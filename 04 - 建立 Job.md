# 04 - 建立 Job
首先建立一個設定 Job 的 class `BCH001JobConfig`，在這個檔案裡面我們會注入 `JobBuilderFactory` 來建立 Job。Job 本身是一個 interface，實作 Job 的實體類別有像是 `AbstractJob`、`FlowJob`、`GroupAwareJob`、`JsrFlowJob` 以及 `SimpleJob`......等等。而 `JobBuilderFactory` 是基於 Builder Design Pattern 概念設計的，所以在建立 Job 的過程中可以一直串接方法，直到最後用 `build()` 結尾。
由於最終是要對 spring 容器注入設定好的 Job，在 `BCH001JobConfig.java` 內會以方法搭配 `@Bean` 來產生 Job。

```
spring.batch.exapmle.job // 新增
  |--BCH001JobConfig.java // 新增
```
`BCH001JobConfig.java`
```java
public class BCH001JobConfig {
  
  /** JobBuilderFactory */
  @Autowired
  private JobBuilderFactory jobBuilderFactory;
  
  // 要引入的 Repo
  
  /**
   * 註冊 job
   * @param step
   * @return
   */
  public Job bch001Job(){
    return jobBuilderFactory.get("BCH001Job")
      .start(step)
      .listener(new BCH001JobListener)
      .build();
  }
}
```

`JobBuilderFactory` 內的 `get()` 方法，會回傳 `JobBuilder` 實例，接著我們就可以繼續用 `JobBuilder` 內部的方法繼續建立想要的 Job。傳入的 `name` 會透過 JobBuilder 建構式對 Job 進行命名。下面是 JobFactory 內的 `get()` 方法：
```java
/**
 * Creates a job builder and initializes its job repository. Note that if the builder is used to create a &#64;Bean
 * definition then the name of the job and the bean name might be different.
 * 
 * @param name the name of the job
 * @return a job builder
 */
public JobBuilder get(String name) {
  JobBuilder builder = new JobBuilder(name).repository(jobRepository);
  return builder;
}
```

而如果需要監聽 Job 的話也可以使用 `listener()` 加入監聽器來監控狀況。
```
spring.batch.exapmle.job
  |--BCH001JobConfig.java 
spring.batch.exapmle.listener // 新增
  |--BCH001JobListener.java // 新增
```

`BCH001JobListener.java`
```java
/**
 * JBCHRESID001 JobListener
 */
public class BCH001JobListener implements JobExecutionListener {
    
    private static final Logger LOGGER = LoggerFactory.getLogger(BCH001JobListener.class);

    @Override
    public void beforeJob(JobExecution jobExecution) {
        LOGGER.info("BCH001Job: 批次開始");
    }

    @Override
    public void afterJob(JobExecution jobExecution) {
        LOGGER.info("BCH001Job: 批次結束");
    }
}
```

## 參考
* https://www.toptal.com/spring/spring-batch-tutorial
* https://www.javadevjournal.com/spring-batch/spring-batch-job-configuration/
