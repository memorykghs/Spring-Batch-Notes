# 05 - 建立 Step

Step 物件封裝了批次處理作業的一個獨立的、有順序的階段。在 Step 中可以自行定義及控制實際批次處理所需要的所有訊息，例如如何讀取、如何處理讀取後的資料等等。一個簡單的 Step 也許只需要簡短的程式，而複雜的業務邏輯也可以透過 Step 的架構來進行設計及處理。

一個 Step 中可以包含 ItemReader、ItemProcessor 及 ItemWriter 這三個物件，分別用來讀取資料、對資料進行處理，以及有需要的時候輸出資料，架構如下：<br/>
![](/images/5-1.png)

Spring Batch 中最常見的處理風格其實是 **chunk-orientd**，指的是一次讀取某一個設定好的數量的資料區塊，一旦讀取的項目數量等於所設定的提交間隔 ( commit interval )，這"塊"資料就會交由 ItemWriter 進行交易並 commit。大智的流程如下：<br/>
![](/images/5-2.png)

ItemReader 會反覆的讀取資料，直到達到提交間隔數量，就會進行輸出。當然，也可以在讀取資料後透過 ItemProcessor 處理資料，然後再由 ItemWriter 輸出。當讀取完一"塊"資料後，才會統一往下給 ItemProcessor 處理，概念如下：<br/>
![](/images/5-3.png)

接下來就開始建立一個 Step。
```
spring.batch.exapmle.job
  |--BCH001JobConfig.java // 修改
spring.batch.exapmle.listener 
  |--BCH001JobListener.java // 新增
```
<br/>

1. `BCH001JobConfig.java`
```java
public class BCH001JobConfig {
  
  /** JobBuilderFactory */
  @Autowired
  private JobBuilderFactory jobBuilderFactory;

  /** StepBuilderFactory */
  @Autowird
  private StepBuilderFactory stepBuilderFactory;
  
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

  /**
  * 註冊 Step
  * @param itemReader
  * @param process
  * @param itemWriter
  * @param jpaTransactionManager
  * @return
  */
  @Bean(name = "BCH001Step1")
  private Step BCH001Step1(ItemReader<Map<String, Object>> itemReader, BCH001Processor process, ItemWriter<BsrResvResidual> itemWriter,
          JpaTransactionManager jpaTransactionManager) {
      return stepBuilderFactory.get("BCH001Step1")
              .transactionManager(jpaTransactionManager)
              .<Map<String, Object>, BsrResvResidual> chunk(FETCH_SIZE)
              .reader(itemReader)
              .processor(process)
              .faultTolerant()
              .skip(Exception.class)
              .skipLimit(Integer.MAX_VALUE)
              .writer(itemWriter)
              .listener(new BCH001ReaderListener())
              .listener(new BCH001ProcessListener())
              .listener(new BCH001WriterListener())
              .listener(new BCH001StepListener())
              .build();
  }
```

在上面的步驟中，同樣透過 StepBuilderFactory 的 `get()` 方法取得 StepBuilder 物件，並為這個產生出來的 Step 實例進行命名。後面則包含了一些在建立 Step 過程中所需的依賴：
* `reader()`：註冊 ItemReader 並由 ItemReader 讀取要處理的項目。
* `transactionManager()`：Spring 提供 `PlatformTransactionManager` 類別，用來在處理資料時進行交易 ( begins and commit )。
* `chunk()`：用來設定每批資料的數量。

需要注意的是，`PlatformTransactionManager` 是通過加在類別上的 `@EnableBatchProcessing` 標註取得默認的物件實例，可以用 `@Autowired` 或是當作傳入參數注入到產生 Step 的方法中。

另外還有一些東西可以進行設定：
* `processor()`：若資料中間有需要進行轉換或處理的，可以新增 process 流程。
* `writer()`：輸出或 commit ItemReader 提供的項目。
<br/>

* `skip()`：在處理的過程中假設遇到某些作物，但不希望 Step 因為例外導致運行失敗，可以使用此方法被配置要跳過的邏輯。上面的例子就是當出現例外的時候要跳過，並繼續下面的批次。
<br/>

* `noSkip()`：有些例外可以配置跳過，當然也可以設定出現某些例外時不能跳過，放在此方法內的例外將導致 Step 運行中止。另外 `skip()` 與 `.noSkip()` 放置的前後順序不會影響流程。

通常 Step 只會運行一次，不過在某些情況下我們希望可以控制 Step 啟動的次數，就可以用 `.startLimit(times)` 方法來設定。

## 參考
* https://medium.com/@softjobdays/springbatch%E7%B0%A1%E4%BB%8B-1b3ef3b8d73e 
* https://docs.spring.io/spring-batch/docs/4.2.x/reference/html/step.html#configureStep
