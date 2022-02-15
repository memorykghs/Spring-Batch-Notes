# 05 - 建立 Step 與 StepListener

## 建立 Step
Step 物件封裝了批次處理作業的一個獨立的、有順序的階段。在 Step 中可以自行定義及控制實際批次處理所需要的所有訊息，例如如何讀取、如何處理讀取後的資料等等。一個簡單的 Step 也許只需要簡短的程式，而複雜的業務邏輯也可以透過 Step 的架構來進行設計及處理。

一個 Step 中可以包含 ItemReader、ItemProcessor 及 ItemWriter 這三個物件，分別用來讀取資料、對資料進行處理，以及有需要的時候輸出資料，架構如下：<br/>
![](/images/5-1.png)

Spring Batch 中最常見的處理風格其實是 **Chunk-oriented**，指的是一次讀取某一個設定好的數量的資料區塊，一旦讀取的項目數量等於所設定的提交間隔 ( commit interval )，這"塊"資料就會交由 ItemWriter 進行交易並 commit。大至的流程如下：<br/>
![](/images/5-2.png)

ItemReader 會反覆的讀取資料，直到達到提交間隔數量，就會進行輸出。當然，也可以在讀取資料後透過 ItemProcessor 處理資料，然後再由 ItemWriter 輸出。當讀取完一"塊"資料後，才會統一往下給 ItemProcessor 處理，概念如下：<br/>
![](/images/5-3.png)

接下來就開始建立一個 Step。
```
spring.batch.springBatchExample.batch.job
  |--DbReaderJobConfig.java // 修改
spring.batch.springBatchExample.batch.listener 
  |--Db001JobListener.java
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

	/**
	 * 建立 Step
	 * @param itemReader
	 * @param itemWriter
	 * @param transactionManager
	 * @return
	 */
	@Bean("Db001Step")
	public Step dbReaderStep(@Qualifier("Db001JpaReader") ItemReader<Cars> itemReader, @Qualifier("Db001FileWriter") ItemWriter<Cars> itemWriter,
			JpaTransactionManager transactionManager) {

		return stepBuilderFactory.get("Db001Step")
			.transactionManager(transactionManager)
			.<Cars, Cars>chunk(FETCH_SIZE)
			.faultTolerant()
			.skip(Exception.class)
			.skipLimit(Integer.MAX_VALUE)
			.build();
		}
}
```

在上面的步驟中，同樣透過 StepBuilderFactory 的 `get()` 方法取得 StepBuilder 物件，並為這個產生出來的 Step 實例進行命名。後面則包含了一些在建立 Step 過程中所需的依賴：
* `reader()`：註冊 ItemReader 並由 ItemReader 讀取要處理的項目。
* `transactionManager()`：Spring 提供 `PlatformTransactionManager` 類別，用來在處理資料時進行交易 ( begins and commit )。
  
  需要注意的是，`PlatformTransactionManager` 是通過加在類別上的 `@EnableBatchProcessing` 標註取得默認的物件實例，可以用 `@Autowired` 或是當作傳入參數注入到產生 Step 的方法中。而如果像上面這個例子是沒有加上 `@EnableBatchProcessing` 標註的話，就需要另外注入。
  
  這邊預設使用的是 `JpaTransactionManager`，使用此類別需要多 import dependency：
  ```xml
  <dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-data-jpa</artifactId>
  </dependency>
  ```
  <br/>
* `chunk()`：用來設定每批資料的數量，泛型的第一個參數是輸入的資料格式，後面的代表經過處理後，要用 ItemWriter 輸出的資料格式。
<br/>

   

* `reader()`：註冊 ItemReader 並由 ItemReader 讀取要處理的項目。
* `processor()`：若資料中間有需要進行轉換或處理的，可以新增 process 流程。
* `writer()`：輸出或 commit ItemReader 提供的項目。
<br/>

* `faultTolerant()`：回傳 FaultTolerantStepBuilder，此 Builder 才能設訂 Skip 相關的參數。
* `skip()`：在處理的過程中假設遇到某些作物，但不希望 Step 因為例外導致運行失敗，可以使用此方法被配置要跳過的邏輯。上面的例子就是當出現例外的時候要跳過，並繼續下面的批次。
* `skipLimit()`：與 `skip()` 搭配使用，設定跳過的上限次數。
* `noSkip()`：有些例外可以配置跳過，當然也可以設定出現某些例外時不能跳過，放在此方法內的例外將導致 Step 運行中止。另外 `skip()` 與 `.noSkip()` 放置的前後順序不會影響流程。
<br/>

* `listener()`：可以對某些對象建立監聽器來監控流程。

通常 Step 只會運行一次，不過在某些情況下我們希望可以控制 Step 啟動的次數，就可以用 `.startLimit(times)` 方法來設定。

#### chunk()
以下為 `chunck()` 在 StepBuilder 中的定義：
```java
/**
 * Build a step that processes items in chunks with the size provided. To extend the step to being fault tolerant,
 * call the {@link SimpleStepBuilder#faultTolerant()} method on the builder. In most cases you will want to
 * parameterize your call to this method, to preserve the type safety of your readers and writers, e.g.
 *
 * @param chunkSize the chunk size (commit interval)
 * @return a {@link SimpleStepBuilder}
 * @param <I> the type of item to be processed as input
 * @param <O> the type of item to be output
 */
public <I, O> SimpleStepBuilder<I, O> chunk(int chunkSize) {
  return new SimpleStepBuilder<I, O>(this).chunk(chunkSize);
}
```
前面會傳入泛型，第一個參數為輸入 ( Input ) 的資料集合的類別，後面的則是要輸出的資料類別。使用 StepBuilderFactory 的 `get()` 方法會拿到 StepBuilder 物件，接著呼叫 `chunk()` 的時候會將當前的 StepBuilder 物件傳入，並透過建構式再回傳有設定泛型的 StepBuilder 物件。
<br/>

## 建立 StepListener
在 Spring Batch 中，所有的 Step Listener 都是繼承自 StepListener 這個介面。
```java
package org.springframework.batch.core;
public interface StepListener {
  ......
}
```

而我們使用的是 StepExecutionListener，這個介面提供一些阻斷 ( interceptions ) 及生命週期 ( life-cycle ) 相關的方法。實作該介面會有兩個一定要 override 的方法，分別是 `beforeStep()` 及 `afterStep()`，可以透過這兩個方法在執行 Step 的前後做一些處理。`afterStep()` 會回傳一個 `ExitStatus` 狀態代碼，如 `EXECUTING`、`COMPLETED`、`STOPPED` 等等，來表示這次 Step 的執行是否成功 ( 後面會提到這個退出代碼是可以自訂的 )。

```
spring.batch.springBatchExample.batch.job
  |--DbReaderJobConfig.java // 修改
spring.batch.springBatchExample.batch.listener 
  |--Db001JobListener.java
  |--Db001StepListener.java // 新增
```

* `Db001StepListener.java`
```java
public class Db001StepListener implements StepExecutionListener{
  private static final Logger LOGGER = LoggerFactory.getLogger(Db001StepListener.class);

  @Override
  public void beforeStep(StepExecution stepExecution) {
      LOGGER.info("開始讀檔");
  }

  @Override
  public ExitStatus afterStep(StepExecution stepExecution) {
      String msg = new StringBuilder()
              .append("Db001Step: 讀取DB Table筆數: ")
              .append(stepExecution.getReadCount())
              .append(", 成功筆數: ")
              .append(stepExecution.getWriteCount())
              .append(", 失敗筆數: ")
              .append(stepExecution.getSkipCount()).toString();
      LOGGER.info(msg);
      return ExitStatus.COMPLETED;
  }
}
```

建立 ItemReaderListener 後就可以使用 `listener()` 方法在 `DbReaderJobConfig.java` 中注入 Listener。

* `DbReaderJobConfig.java`
```java
@Bean("Db001Step")
public Step dbReaderStep(JpaTransactionManager transactionManager) {

  return stepBuilderFactory.get("Db001Step")
      .transactionManager(transactionManager)
      .<Cars, Cars>chunk(FETCH_SIZE)
      .faultTolerant()
      .skip(Exception.class)
      .skipLimit(Integer.MAX_VALUE)
      .listener(new Db001StepListener()) // 新增
      .build();
}
```

## 參考
* https://medium.com/@softjobdays/springbatch%E7%B0%A1%E4%BB%8B-1b3ef3b8d73e 
* https://docs.spring.io/spring-batch/docs/4.2.x/reference/html/step.html#configureStep
* https://www.javadevjournal.com/spring-batch/spring-batch-listeners/
