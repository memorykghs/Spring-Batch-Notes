# 17 - 建立 ItemWriter、ItemWriterListener 並寫入資料庫
ItemWriter 在功能上與 ItemReader 類似，不過是相反的操作；相較於 ItemReader 每次以一個 `item` ( 一筆資料 ) 為單位循環讀取，ItemWriter 則是以一個 `chunk` 為一批，一塊一塊輸出。大部分的情況下，這些操作可以是插入、更新或發送。ItemWriter 介面如下：
```java
public interface ItemWriter<T> {

	/**
	 * Process the supplied data element. Will not be called with any null items
	 * in normal operation.
	 *
	 * @param items items to be written
	 * @throws Exception if there are errors. The framework will catch the
	 * exception and convert or rethrow it as appropriate.
	 */
	void write(List<? extends T> items) throws Exception;

}
```

ItemWriter 會接收一個以集合封裝的物件，並透過呼叫 `write()` 方法進行資料的輸出或是異動。實作 ItemWriter 的物件實例有許多，可以參考：https://docs.spring.io/spring-batch/docs/current/reference/html/index-single.html#itemWritersAppendix 。

## 建立 ItemWriter

```
spring.batch.springBatchPractice.job
  |--DbReaderJobConfig.java
  |--FileReaderJobConfig.java // 修改
```

* `FileReaderJobConfig.java`
```java
@Configuration
public class FileReaderJobConfig {
  ...
  ...

    /**
     * 建立 Jpa ItemWriter
     * @return
     */
    @Bean("File001JpaWriter")
    public ItemWriter<Car> getItemWriter(){
      
      return new RepositoryItemWriterBuilder<Car>()
          .repository(carRepo)
          .methodName("save")
          .build();
    }
}
```
`ItemWriter<>` 介面的泛型型別，要設定成輸入的資料型別，也就是透過 ItemReader 或是 ItemProcess 轉換後的資料格式。

與寫入資料庫搭配的是 `RepositoryItemWriter`，這邊用 `RepositoryItemWriterBuilder` 建立 ItemWriter。

`repository()` 設定要使用的 Repo、`methodName()` 指定使用的方法即可。最後呼叫 `build()` 方法建立 `RepositoryItemWriter` 物件。比起前面設定 `FlatFileItemReader` 相對簡單。

建立完成後要在 Step 方法上加入 ItemWriter。

```java
@Configuration
public class FileReaderJobConfig {
  ...
  ...
    /**
      * 註冊 Step
      * @param itemReader
      * @param itemWriter
      * @param jpaTransactionManager
      * @return
      */
    @Bean("File001Step")
    public Step fileReaderStep(@Qualifier("File001FileReader") ItemReader<Car> itemReader, @Qualifier("File001JpaWriter") ItemWriter<Car> itemWriter,
        JpaTransactionManager jpaTransactionManager) { // 修改

      return stepBuilderFactory.get("File001Step")
          .transactionManager(jpaTransactionManager)
          .<Car, Car>chunk(FETCH_SIZE)
          .reader(itemReader)
          .faultTolerant()
          .skip(Exception.class)
          .skipLimit(Integer.MAX_VALUE)
          .writer(itemWriter) // 新增
          .listener(new File001StepListener())
          .listener(new File001ReaderListener())
          .build();
    }
    
    ...
    ...

    /**
     * 建立 Jpa ItemWriter
     * @return
     */
    @Bean("File001JpaWriter")
    public ItemWriter<Car> getItemWriter(){
      
      return new RepositoryItemWriterBuilder<Car>()
          .repository(carRepo)
          .methodName("save")
          .build();
    }
}
```

在建立 Step 的 `fileReaderStep()` 方法中以參數的形式注入 ItemWrtiter，一般情況下 ItemWriter 的泛型型別不同會被視為不同的 Bean，如果型別相同的話，就需要使用 `@Qualifier` 來指明需要注入哪個特定的 Bean。然後在該方法內用 StepBuilder 的 `writer()` 及 `listener()` 方法加入前面建立的 ItemWriter 和 ItemWriterListener 物件。

## 建立 ItemWriterListener
接下來我們要對 ItemWriter 進行監聽，新增一個 ItemWriterListener。

```
spring.batch.springBatchPractice.job
  |--DbReaderJobConfig.java
  |--FileReaderJobConfig.java // 修改
spring.batch.springBatchPractice.listener
  |--File001StepListener.java
  |--File001ReaderListener.java
  |--File001JobListener.java
  |--File001WriterListener.java // 新增
```

繼承 `ItemWriterListener` 介面並附寫其方法即可。
* `File001WriterListener.java`
```java
public class File001WriterListener implements ItemWriteListener<CarsDto> {
    
    private static final Logger LOGGER = LoggerFactory.getLogger(File001WriterListener.class);

    @Override
    public void beforeWrite(List<? extends CarsDto> items) {
        LOGGER.info("寫入資料開始");
    }

    @Override
    public void afterWrite(List<? extends CarsDto> items) {
        LOGGER.info("寫入資料結束");
    }

    @Override
    public void onWriteError(Exception ex, List<? extends CarsDto> items) {
        LOGGER.error("File001Writer: 寫入資料失敗", ex);
    }
}
```
<br/>

然後修改 JobConfig 檔案，將 `ItemWriterListener` 加入。
* `BCHBORED001JobConfig.java`
```java
@Configuration
public class FileReaderJobConfig {

    /** JobBuilderFactory */
    @Autowired
    private JobBuilderFactory jobBuilderFactory;

    /** StepBuilderFactory */
    @Autowired
    private StepBuilderFactory stepBuilderFactory;

    /** CarRepo */
    @Autowired
    private CarRepo carRepo;

    /** Mapping 欄位名稱 */
    private static final String[] MAPPER_FIELD = new String[] { "Manufacturer", "Type", "MinPrice", "Price" };

    /** 每批件數 */
    private static final int FETCH_SIZE = 1;

    /**
      * 註冊 Job
      * @param step
      * @return
      */
    @Bean("File001Job")
    public Job fileReaderJob(@Qualifier("File001Step") Step step) {
      return jobBuilderFactory.get("File001Job")
          .start(step)
          .listener(new File001JobListener())
          .build();
    }

	/**
	 * 註冊 Step
	 * @param itemReader
	 * @param itemWriter
	 * @param jpaTransactionManager
	 * @return
	 */
    @Bean("File001Step")
    public Step fileReaderStep(@Qualifier("File001FileReader") ItemReader<Car> itemReader, @Qualifier("File001JpaWriter") ItemWriter<Car> itemWriter,
      JpaTransactionManager jpaTransactionManager) {

    return stepBuilderFactory.get("File001Step")
        .transactionManager(jpaTransactionManager)
        .<Car, Car>chunk(FETCH_SIZE)
        .reader(itemReader)
        .faultTolerant()
        .skip(Exception.class)
        .skipLimit(Integer.MAX_VALUE)
        .writer(itemWriter)
        .listener(new File001StepListener())
        .listener(new File001ReaderListener())
        .listener(new File001WriterListener()) // 新增
        .build();
    }

    ...
    ...

    /**
     * 建立 Jpa ItemWriter
     * @return
     */
    @Bean("File001JpaWriter")
    public ItemWriter<Car> getItemWriter(){
      
      return new RepositoryItemWriterBuilder<Car>()
          .repository(carRepo)
          .methodName("save")
          .build();
    }
}
```

## 參考
* https://docs.spring.io/spring-batch/docs/current/reference/html/index-single.html#itemWriter
* https://www.itread01.com/content/1539261642.html
