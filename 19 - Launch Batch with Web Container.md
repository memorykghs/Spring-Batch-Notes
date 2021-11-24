# 19 - 使用 Web Container 設定
Spring Batch 是一個可以依附在 Spring 應用程式環境的輕量級框架，表示 Spring Batch 可以在 Web 應用程式的環境下隨時使用，不需要特別使用 run as Java Application 啟動它，也可以在 Web 應用程式中使用 schedule 排程。

下圖代表了應用程式環境可以包含 Spring 執行環境。<br/>
![](/images/19-1.png)

讓 Spring Batch 依附在應用程式中非常方便，在進一步於這種架構下通過 Http 請求觸發批次作業前，我們先來看看如何在 Web 應用程式中配置 Spring Batch。

## 在 Web 應用程式中遷入 Spring Batch
Spring Framework 提供了一個 servlet 偵聽器類別 `ContextLoaderListener`，`ContextLoaderListener` 會根據 Web 應用程式的生命週期管理執行環境的生命週期。

預設情況下，`ContextLoaderListener` 類使用 Web 應用程式的 `WEB-INF` 目錄中的 `applicationContext.xml` 文件來建立應用程式的環境，裡面應包含 Spring Batch Infrastructure、Job、schedule ( 如果有 ) 和應用程序服務的配置。<br/>

![](/images/19-2.png)

## 使用 Http Request 搭配 crontab 啟動 Job
假設現在在 Web 應用程式中部署了 Spring Batch 環境，並且想要用 System Scheduler 像是 cron 來觸發批次作業，但是 cron 該如何觸發現在在 Web 應用程式中的 Spring Batch 呢?

所以我們可以在 crontab 中執行命令，以 HTTP 請求的模式打給 Web 應用程式。以下是使用 wget 等命令行工具執行 HTTP 請求的架構圖：<br/>

![](/images/19-3.png)

## 在 Web 應用程式中配置 Spring Batch
首先先在 `pom.xml` 中加入 Web Application 要用的 dependency。
```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-web</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-test</artifactId>
    <scope>test</scope>
</dependency>
<!-- spring-boot-jdbc -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-jdbc</artifactId>
</dependency>
<!-- 檔案異動後server自動重啟 -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-devtools</artifactId>
    <optional>true</optional>
</dependency>
```

因為要用 HTTP Request 打到 Web 應用程式的 Controller 再啟動 Job，所以我們要讓 `JobLauncher` 可以在 Controller 中被 `@Autowired` 出來。下面會在 `BatchConfig` 中進行一些設定。
```
spring.batch.springBatchPractice.config
  |--BatchConfig.java // 修改
```

* `BatchConfig.java`
```java
@Configuration
public class BatchConfig {
    ...
    ...
    /**
     * <pre>
     * 建立 JobLauncher
     * for Web Container
     * </pre>
     * 
     * @param jobRepository
     * @return
     * @throws Exception
     */
    @Bean
    public SimpleJobLauncher jobLauncher(JobRepository jobRepository) throws Exception {
        SimpleJobLauncher jobLauncher = new SimpleJobLauncher();
        jobLauncher.setJobRepository(jobRepository);
        jobLauncher.setTaskExecutor(new SimpleAsyncTaskExecutor()); // web container 一般會設定非同步
        jobLauncher.afterPropertiesSet();

        return jobLauncher;
    }
}
```

設定好後接著建立 Controller，並把 Application 啟動點的程式碼搬過來。
```
spring.batch.springBatchPractice
  |--SpringBatchExmapleApplication.java // 修改
spring.batch.springBatchPractice.controller
  |--BatchContoller.java // 修改
```

* `SpringBatchExmapleApplication.java`
```java
@SpringBootApplication
@EnableBatchProcessing
public class SpringBatchExmapleApplication {

    public static void main(String[] args) {
        try {
            SpringApplication.run(SpringBatchExmapleApplication.class, args);

        } catch (Exception e) {
            LOGGER.error("springBatchPractice執行失敗", e);
        }
    }
}
```
在 Application 中會移除掉 `JobLauncher` 啟動、以及產生 `JobParameters` 的方法，改由在 Controller 做。
<br/> 


* `BatchController.java`
```java
@Api(tags = "Spring Batch Examples")
@RestController
public class BatchController {

    /** LOG */
    private static final Logger LOGGER = LoggerFactory.getLogger(BatchController.class);

    @Autowired
    private JobRegistry jobRegistry;

    @Autowired
    private JobLauncher jobLauncher;

    /**
     * call by web conatiner
     * 
     * @throws JobExecutionAlreadyRunningException
     * @throws JobRestartException
     * @throws JobInstanceAlreadyCompleteException
     * @throws JobParametersInvalidException
     */
    @ApiOperation(value = "執行讀DB批次")
    @RequestMapping(value = "/dbReader001Job", method = RequestMethod.POST)
    public String doDbReader001Job() {

        try {
            jobLauncher.run(jobRegistry.getJob("Db001Job"), createJobParams("Db001Job"));
        } catch (JobExecutionAlreadyRunningException | JobRestartException | JobInstanceAlreadyCompleteException
					| JobParametersInvalidException | NoSuchJobException e) {
            e.printStackTrace();
        }

        return "finished";
    }

    /**
        * 產生JobParameter
        * 
        * @return
        */
    private JobParameters createJobParams(String jobName) {

        JobParametersBuilder builder = new JobParametersBuilder();
        builder.addDate("executeTime", Timestamp.valueOf(LocalDateTime.now()));

        return builder.toJobParameters();
    }
}
```

這邊我們打到前面寫過的讀取 DB 資料的批次，用 `JobRegistry` 依照 Job 名稱取出，並呼叫 `createJobParams()` 方法取得 `JobParameters`。

而 catch 的部分，`JobLauncher` 的 `run()` 方法本身就有機會拋出下面這些 Exception。

```
小 JobExecutionAlreadyRunningException
|  JobRestartException
|  JobInstanceAlreadyCompleteException
|  JobParametersInvalidException
V  BeansException
大 NoSuchJobException
```

可以視情況而定，決定要不要在每個例外被拋出來時印出不同的 log。
```java
try {
    jobLauncher.run(jobRegistry.getJob("Db001Job")

} catch (JobExecutionAlreadyRunningException jobExecutionAlreadyRunningException) {
    LOGGER.info("Job execution is already running.");

} catch (JobRestartException jobRestartException) {
    LOGGER.info("Job restart exception happens.");

} catch (JobInstanceAlreadyCompleteException jobInstanceAlreadyCompleteException) {
    LOGGER.info("Job instance is already completed.");

} catch (JobParametersInvalidException jobParametersInvalidException) {
    LOGGER.info("Job parameters invalid exception");

} catch (BeansException beansException) {
    LOGGER.info("Bean is not found.");

} catch (NoSuchJobException e) {
    e.printStackTrace();
}
```

回頭想一下，原本我們在 Application 中建立一個私有方法來創造 `JobParameters` 實例，是因為我們必須依照啟動的 `JobName` 來判斷要給的參數。不過現在是透過 HTTP Request 觸發，所以就不需要在判斷要傳入什麼 `JobName`，可以傳入固定的參數。

那問題來了，前面提到說每個 `JobInctance` = `Job` + `identifying JobParameters`，這樣每次執行還是需要不同的 `JobParamters` 啊?那為什麼說可以傳入相同的參數就好呢?

因為我們可以在方法中設定 `JobParametersIncrementer`，讓每次執行的 Job 都是不一樣的，下面直接來看扣要怎麼改。

```
spring.batch.springBatchPractice
  |--SpringBatchExmapleApplication.java
spring.batch.springBatchPractice.controller
  |--BatchConfig.java // 修改
spring.batch.springBatchPractice.batch.job
  |--DbReaderJobConfig.java // 修改
```

* `BatchController.java`
```java
@Api(tags = "Spring Batch Examples")
@RestController
public class BatchController {

    /** LOG */
    private static final Logger LOGGER = LoggerFactory.getLogger(BatchController.class);

    @Autowired
    private JobRegistry jobRegistry;

    @Autowired
    private JobLauncher jobLauncher;

    /**
     * call by web conatiner
     * 
     * @throws JobExecutionAlreadyRunningException
     * @throws JobRestartException
     * @throws JobInstanceAlreadyCompleteException
     * @throws JobParametersInvalidException
     */
    @ApiOperation(value = "執行讀DB批次")
    @RequestMapping(value = "/dbReader001Job", method = RequestMethod.POST)
    public String doDbReader001Job() {

        try {
            jobLauncher.run(jobRegistry.getJob("Db001Job"), new JobParameters());

        } catch (JobExecutionAlreadyRunningException | JobRestartException | JobInstanceAlreadyCompleteException
					| JobParametersInvalidException | NoSuchJobException e) {
            e.printStackTrace();
        }

        return "finished";
    }
}
```
<br/>

* `DbReaderJobConfig.java` 
```java
@Configuration
public class DbReaderJobConfig {
    ...
    ...
    @Bean
    public Job dbReaderJob(@Qualifier("Db001Step") Step step) {
        return jobBuilderFactory.get("Db001Job")
                .incrementer(new RunIdIncrementer()) // 新增 Incrementer
                .start(step)
                .listener(new Db001JobListener())
                .build();
    }
}
```

這樣就不需要每次都要產生不同的 `JobParameter`。

![](/images/icon-question.png) JobLauncher 可以不用傳參數進去嗎?

## 參考
* https://docs.spring.io/spring-batch/docs/4.3.x/reference/html/job.html#runningJobsFromWebContainer
* https://livebook.manning.com/book/spring-batch-in-action/chapter-4/197
* https://stackoverflow.com/questions/53687925/how-to-launch-spring-batch-job-asynchronously
