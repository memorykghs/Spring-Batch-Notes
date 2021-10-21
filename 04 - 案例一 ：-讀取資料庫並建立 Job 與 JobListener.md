# 04 - 讀取資料庫並建立 Job 與 JobListener
## 建立 Job
假設現在的需求是需要從資料庫讀取數據，整理資料後寫入另外一張表格。為了達到這個目的，首先建立一個用來設定 Job 的 class `dbReaderJobConfig`，在這個檔案裡面我們會注入 `JobBuilderFactory` 來建立 Job。

Job 本身是一個 interface，實作 Job 的實體類別有像是 `AbstractJob`、`FlowJob`、`GroupAwareJob`、`JsrFlowJob` 以及 `SimpleJob`......等等。而 `JobBuilderFactory` 是基於 Builder Design Pattern 概念設計的，所以在建立 Job 的過程中可以一直串接方法，直到最後用 `build()` 結尾。

由於最終是要對 spring 容器注入設定好的 Job，在 `dbReaderJobConfig.java` 內會以方法搭配 `@Bean` 來產生 Job。

```
spring.batch.springBatchExample.job // 新增
  |--dbReaderJobConfig.java // 新增
```
<br/>

* `DbReaderJobConfig.java`
```java
@Configuration
public class DbReaderJobConfig {

	/** JobBuilderFactory */
	@Autowired
	private JobBuilderFactory jobBuilderFactory;

	/** StepBuilderFactory */
	@Autowired
	private StepBuilderFactory stepBuilderFactory;

	/** 每批件數 */
	private static int FETCH_SIZE = 10;
	
	/**
	 * 建立 Job
	 * 
	 * @param step
	 * @return
	 */
	@Bean
	public Job dbReaderJob(@Qualifier("Db001Step") Step step) {
		return jobBuilderFactory.get("Db001Job")
				.start(step)
				.listener(new Db001JobListener())
				.build();
	}
}
```
在 `dbReaderJob()` 方法中注入 Step，Step 物件會在下一個章節建立。專案中如果建立不只一個 Step 時，注入到 Job 中必須以 `@Qualifier` 來指定要的實力物件是哪一個類別的。再來，`JobBuilderFactory` 內的 `get()` 方法，會回傳 `JobBuilder` 實例，接著我們就可以繼續用 `JobBuilder` 內部的方法繼續建立想要的 Job。傳入的 `name` 會透過 JobBuilder 建構式對 Job 進行命名。下面是 JobFactory 內的 `get()` 方法：
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

## 建立 JobListener
如果需要監聽 Job 的話也可以使用 `listener()` 加入監聽器來監控狀況。
```
spring.batch.springBatchExample.job
  |--dbReaderJobConfig.java 
spring.batch.springBatchExample.listener // 新增
  |--Db001JobListener.java // 新增
```

* `Db001JobListener.java`
```java
public class Db001JobListener implements JobExecutionListener {

	private static final Logger LOGGER = LoggerFactory.getLogger(Db001JobListener.class);

	@Override
	public void beforeJob(JobExecution jobExecution) {
		LOGGER.info("Db001Job: 批次開始");
	}

	@Override
	public void afterJob(JobExecution jobExecution) {
		LOGGER.info("Db001Job: 批次結束");
	}
}
```
`JobExecutionListener` 介面提供一些阻斷 ( interceptions ) 及生命週期 ( life-cycle ) 相關的方法。實作該介面會有兩個一定要 override 的方法，分別是 `beforeJob()` 及 `afterJob()`，可以透過這兩個方法在執行 Job 的前後做一些處理。

## 參考
* https://www.toptal.com/spring/spring-batch-tutorial
* https://www.javadevjournal.com/spring-batch/spring-batch-job-configuration/
