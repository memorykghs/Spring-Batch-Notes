# 06 - 建立 RepositoryItemReader 與 ItemReaderListener

## 建立 ItemReader
ItemReader 顧名思義就是用來讀取資料的，讀取資料的來源大致上可以分為三種：
1. 檔案 ( Flat File )
2. XML
3. 資料庫 ( Database )

Spring Batch 中提供一些已經寫好的 ItemReader 的類別，如 `FlatFileItemReader`、`JpaPagingItemReader`、`RepositoryItemReader`......等等。其中，
* `JpaPagingItemReader` 通常用於使用 JPQL 的狀況，可以搭配 `@Query` 物件撰寫原生 SQL，並以分頁方式讀取。
* `RepositoryItemReader` 是以 Spring Data Jpa 方式讀取，可以傳入的對象包含 `PagingAndSortingRepository` 物件、結果集排序物件 ( `Sorts` ) 等等。

其他 ItemReader 類別可參考以下網址：https://docs.spring.io/spring-batch/docs/current/reference/html/appendix.html#itemReadersAppendix。

接著就來建立 `RepositoryItemReader` 對象。

```
spring.batch.springBatchExample.job
  |--DbReaderJobConfig.java // 修改
spring.batch.springBatchExample.listener 
  |--Db001JobListener.java
  |--Db001StepListener.java
```

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

    /** CarRepo */
    @Autowired
    private CarsRepo carRepo;

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
    public Step dbReaderStep(@Qualifier("Db001JpaReader") ItemReader<Cars> itemReader, JpaTransactionManager transactionManager) { // 加入

        return stepBuilderFactory.get("Db001Step")
                .transactionManager(transactionManager)
                .<Cars, Cars>chunk(FETCH_SIZE)
                .reader(itemReader) // 加入
                .faultTolerant()
                .skip(Exception.class)
                .skipLimit(Integer.MAX_VALUE)
                .listener(new Db001StepListener())
                .build();
    }

    /**
     * 建立 Jpa Reader
     * @return
     */
    @Bean("Db001JpaReader")
    public RepositoryItemReader<Cars> itemReader() {

        // List<String> args = new ArrayList<>();
        // args.add("TOYOTA");

        Map<String, Direction> sortMap = new HashMap<>();
        sortMap.put("Manufacturer", Direction.ASC);
        sortMap.put("Type", Direction.ASC);

        return new RepositoryItemReaderBuilder<Cars>()
                .name("Db001JpaReader")
                .pageSize(FETCH_SIZE)
                .repository(carRepo) // 使用的 Repo
                .methodName("findAll") // Repo 中要用的方法
                .sorts(sortMap) // 必要
                // .arguments(args)
                .build();
    }
}
```
上面使用 `repository()` 定義使用的 Repository，並用 `methodName()` 指定使用 Repository 中的哪一個方法。如果想要對查詢的資料進行排序的話可以使用 `sorts()` API，要傳入一個 Map，`key` 值為要排序的欄位，`value` 則指定排序順序；`sorts()` 方法也必須撰寫否則會報錯。

```java
/**
 * Provides ordering of the results so that order is maintained between paged queries.
 *
 * @param sorts the fields to sort by and the directions.
 * @return The current instance of the builder.
 * @see RepositoryItemReader#setSort(Map)
 */
public RepositoryItemReaderBuilder<T> sorts(Map<String, Sort.Direction> sorts) {
    this.sorts = sorts;
    return this;
}
```
![](/images/icon-bird-1.png) 值得注意的是，這裡對應的欄位大小寫應該依照 Entity 中定義的屬性，而不是資料庫欄位的大小寫，不然會以下錯誤：**No Property Found for Type...**<br/>

![](/images/6-1.png)

為了解決這個問題找遍了 Repository、Entity 甚至 DTO，後來發現是因為排序物件的 `key` 值不對......詳情可參考 [No Property Found for Type](https://stackoverflow.com/questions/19583540/spring-data-jpa-no-property-found-for-type-exception)。<br/>

![](/images/天公伯.jpg)

如果 JPA 方法需要傳入參數，可以使用 `arguments()` 方法，將傳入的參數依照順序放進 List 內傳入。
```java
/**
 * Arguments to be passed to the data providing method.
 *
 * @param arguments list of method arguments to be passed to the repository.
 * @return The current instance of the builder.
 * @see RepositoryItemReader#setArguments(List)
 */
public RepositoryItemReaderBuilder<T> arguments(List<?> arguments) {
    this.arguments = arguments;

    return this;
}
```

## 建立 ItemReaderListener
建立一個 Listener 並實作 ItemReadListener 即可，泛型傳入的是 ItemReader 讀完後回傳的資料格式。
```
spring.batch.springBatchExample.job
  |--DbReaderJobConfig.java // 修改
spring.batch.springBatchExample.listener 
  |--Db001JobListener.java
  |--Db001StepListener.java
  |--Db001ReaderListener.java // 新增
```

* `Db001ReaderListener.java`
```java
public class Db001ReaderListener implements ItemReadListener<CarsDto> {

    private static final Logger LOGGER = LoggerFactory.getLogger(Db001ReaderListener.class);

    @Override
    public void beforeRead() {
    	LOGGER.info("Db001Reader: 讀取資料開始");

    }

    @Override
    public void afterRead(CarsDto item) {
    	System.out.println("==========> " + item.getManufacturer());

    }

    @Override
    public void onReadError(Exception ex) {
        LOGGER.error("Db001Reader: 讀取資料失敗", ex);
    }
}
```
建立 ItemReaderListener 後將實例加入 Step 中。

```java
@Bean("Db001Step")
public Step dbReaderStep(@Qualifier("Db001JpaReader") ItemReader<Cars> itemReader, @Qualifier("Db001FileWriter") ItemWriter<Cars> itemWriter,
        JpaTransactionManager transactionManager) {

    return stepBuilderFactory.get("Db001Step")
            .transactionManager(transactionManager)
            .<Cars, Cars>chunk(FETCH_SIZE)
            .reader(itemReader)
            .faultTolerant()
            .skip(Exception.class)
            .skipLimit(Integer.MAX_VALUE)
            .writer(itemWriter)
            .listener(new Db001StepListener())
            .listener(new Db001ReaderListener()) // 加入
            .build();
}
```

## 參考
* https://blog.csdn.net/kangkanglou/article/details/82623599

###### 梗圖連結
* [天公伯](https://www.google.com/url?sa=i&url=https%3A%2F%2Fdailyview.tw%2FPopular%2FDetail%2F1268&psig=AOvVaw0ahlOrsJqFa-QLVCOk6djg&ust=1634918356034000&source=images&cd=vfe&ved=0CAwQjhxqFwoTCIi1_t3v2_MCFQAAAAAdAAAAABAD)
