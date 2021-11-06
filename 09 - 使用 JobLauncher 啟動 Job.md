# 08 - 使用 JobLauncher 啟動 Job

## 啟動 Job
還記得這張圖嗎?

![](/images/1-2.png)

在 Spring Batch 中要啟動 Job，就需要透過 `JobLauncher`。

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