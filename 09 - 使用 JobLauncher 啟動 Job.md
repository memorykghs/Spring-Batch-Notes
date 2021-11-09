# 09 - 使用 JobLauncher 啟動 Job

## 配置 JobLauncher
還記得這張圖嗎?

![](/images/1-2.png)

在 Spring Batch 中要啟動 Job，就需要透過 `JobLauncher`。

在配置 `JobLauncher` 之前，首先要在 `Application.java` 這個類別上加上 `@EnableBatchProcessing` 註解，讓我們可以運行 Spring Batch。

```java
@SpringBootApplication
@EnableBatchProcessing
public class SpringBatchExmapleApplication {
    ...
    ...
}
```

加上註解後，Spring 會自動幫我們產生與 Spring Batch 相關的 Bean，同時也提供了一個默認的 `JobRegistry` 環境。最常看到實作 `JobLauncher` 介面的物件是 `SimpleJobLauncher`，並且只需要 `JobRepository` 的依賴，以下是官網的範例：

```java
...
// This would reside in your BatchConfigurer implementation
@Override
protected JobLauncher createJobLauncher() throws Exception {
	SimpleJobLauncher jobLauncher = new SimpleJobLauncher();
	jobLauncher.setJobRepository(jobRepository);
	jobLauncher.afterPropertiesSet();
	return jobLauncher;
}
...
```

由於是直接透過 Application 啟動 Job，在 Application 無法使用 `@Autowired` 注入 `JobLauncher`，所以直接從 `ConfigurableApplicationContext` 拿出 `JobLauncher`。

```java
@SpringBootApplication
@EnableBatchProcessing
public class SpringBatchExmapleApplication {

    private static final Logger LOGGER = LoggerFactory.getLogger(SpringBatchExmapleApplication.class);

    public static void main(String[] args) throws NoSuchJobException, JobExecutionAlreadyRunningException,
        JobRestartException, JobInstanceAlreadyCompleteException, JobParametersInvalidException {
        try {
            // String jobName = args[0];
            String jobName = "Db001Job";

            ConfigurableApplicationContext context = SpringApplication.run(SpringBatchExmapleApplication.class, args);
            Job job = context.getBean(JobRegistry.class).getJob(jobName);
            context.getBean(JobLauncher.class).run(job, createJobParams());

        } catch (Exception e) {
            LOGGER.error("springBatchPractice執行失敗", e);
        }
    }
}
```

`JobLauncher` 的 `run()` 方法會傳入兩個參數：`Job` 與 `JobParameters`。

```java
@SpringBootApplication
@EnableBatchProcessing
public class SpringBatchExmapleApplication {

    private static final Logger LOGGER = LoggerFactory.getLogger(SpringBatchExmapleApplication.class);

    public static void main(String[] args) throws NoSuchJobException, JobExecutionAlreadyRunningException,
        JobRestartException, JobInstanceAlreadyCompleteException, JobParametersInvalidException {
        try {
            // String jobName = args[0];
            String jobName = "Db001Job";

            ConfigurableApplicationContext context = SpringApplication.run(SpringBatchExmapleApplication.class, args);
            Job job = context.getBean(JobRegistry.class).getJob(jobName);
            context.getBean(JobLauncher.class).run(job, createJobParams());

        } catch (Exception e) {
            LOGGER.error("springBatchPractice執行失敗", e);
        }
    }

    /**
     * 產生JobParameter
     * @return
     */
    private static JobParameters createJobParams() {

        JobParametersBuilder builder = new JobParametersBuilder();
        builder.addDate("executeTime", Timestamp.valueOf(LocalDateTime.now()));

        return builder.toJobParameters();
    }
}
```

JobParamter 的功能就像前面提到的一樣，提供執行環境判斷是不是相同的 JobInstance。`createJobParams()` 方法中使用 `JobParametersBuilder` 建立 `JobParameters`。`JobParameters` 有 4 種不同的型別可以使用：String、Date、Long、Double。要新增 `JobParameters` 就使用 `addXXX()`方法，XXX 代表不同型別的參數，`JobParametersBuilder` 內有一個記錄所有 Parameters 的 Map，`addXXX()` 方法會將參數存進內部的 Map。

`addXXX()` 方法中會傳入一組 `key` 值與 `value`，用來為參數命名，執行時期也可以透過參數名稱將值取出。最後會傳的時候要呼叫 `JobParametersBuilder` 的 `toParamteters()` 方法，將 `JobParametersBuilder` 內部存的 Map 轉成 `JobParamters`。

## 啟動時重複執行
在使用 Java Config 執行 Spring Batch 的 Job 時，如果不做任何配置，專案在啟動時預設就會執行定義好的 Job，這也就是為什麼會在 console 看到批次 Listener 出現 2 次的原因。如果不想要在專案啟動時執行批次，可以在 `application.properties` 檔案中新增以下設定：

```properties
spring.batch.job.enabled=false
```

## CommendLine
我們可以透過 cmd 來執行一個 Job，傳入的參數是 `schedule.date(date) = 2021/09/19`：
```
java CommandLineJobRunner io.spring.EndOfDayConfiguration endOfDate schedule.date(date)=2021/09/19
```

CommandLineJobRunner 是 Spring Batch 提供的一個具有 `main` 方法的類別，指令內指定從 `io.spring.EndOfDayConfiguration` 這個有標註 `@Configuration` 的檔案中依照設定建立 Job；接下來的 `endOfDate` 則是 Job 的名稱，也就是產生 Job 的 `@Bean` 方法中設定。最後的 `schedule.date(date)=2021/09/19` 是傳入的 JobParameters。

## 參考
* http://www.4k8k.xyz/article/huanyuminhao/110187739
* https://terasoluna-batch.github.io/guideline/5.0.0.RELEASE/en/Ch02_SpringBatchArchitecture.htmls
