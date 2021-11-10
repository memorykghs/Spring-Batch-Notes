# 10 - 建立 ItemProcess
前面只提到了 Reader 跟 Writer，如果想要在讀進來之後，寫出去之前多做一些業務邏輯的處理，就可以選擇使用 ItemProcess。

```java
public interface ItemProcessor<I, O> {

    O process(I item) throws Exception;
}
```

ItemProcess 必須給定傳入對向的型別，以及最後回傳的型別。傳入與最後回傳的型別可以是不一樣的，因為在 ItemProcess 中可以撰寫一些業務邏輯。

我們一樣用 `STUDENT` 中的 `CARS` 表格，從資料庫讀取資料後，把每筆資料的 `PRICE` 減掉 `MIN_PRICE` 算出差價，輸出檔案。這部分的邏輯就會放在 process 中處理。

## 建立 ItemProcessor

```
spring.batch.springBatchExample.batch.job
  |--DbReaderJobConfig.java // 修改
spring.batch.springBatchExample.batch.processor // 新增
  |--DBItemProcessor.java // 新增
spring.batch.springBatchExample.dto
  |--CarsDto.java // 新增
```

先建立一個 DTO 用來裝轉換完的資料。
* `CarsDto.java`
```java
@Data
public class CarsDto implements Serializable {

    private static final long serialVersionUID = 1L;

    private String manufacturer;

    private String type;
    
    private BigDecimal spread;
}
```

接下來新增 ItemProcessor。

* `DBItemProcessor.java`
```java
@Component
public class DBItemProcessor implements ItemProcessor<Cars, CarsDto> {

    @Override
    public CarsDto process(Cars item) throws Exception {

        // 計算每一廠牌汽車底價及售價價差
        CarsDto carsDto = new CarsDto();
        carsDto.setManufacturer(item.getManufacturer());
        carsDto.setType(item.getType());
        carsDto.setSpread(item.getPrice().subtract(item.getMinPrice()));
        return carsDto;
    }
}
```

`DBItemProcessor` 接收讀到的 Entity `Cars` 為傳入對象，轉換完的資料我們另外建立一個 DTO `CarsDto` 容器存放。也就是說經過 ItemProcess 轉換完的資料格式是 `CarsDto` 🚗🚓🚕。

最後一樣要在 JobConfig 將寫好的 ItemProcessor 註冊進去。

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
    
    /** Mapper Field */
    private static final String[] MAPPER_FIELD = new String[] { "Manufacturer", "Type", "Spread" };

    /** Header */
    private final String HEADER = new StringBuilder().append("製造商").append(',').append("類別").append(',').append("價差").toString();

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

    /**
     * 建立 Step
     * 
     * @param itemReader
     * @param itemWriter
     * @param transactionManager
     * @return
     */
    @Bean("Db001Step")
    public Step dbReaderStep(@Qualifier("Db001JpaReader") ItemReader<Cars> itemReader, @Qualifier("Db001FileWriter") ItemWriter<CarsDto> itemWriter,
            ItemProcessor<Cars, CarsDto> processor, JpaTransactionManager transactionManager) { // 注入

        return stepBuilderFactory.get("Db001Step")
                .transactionManager(transactionManager)
                .<Cars, CarsDto>chunk(FETCH_SIZE)
                .faultTolerant()
                .skip(Exception.class)
                .skipLimit(Integer.MAX_VALUE)
                .reader(itemReader)
                .processor(processor) // 加入
                .writer(itemWriter)
                .listener(new Db001StepListener())
                .listener(new Db001ReaderListener())
                .listener(new Db001WriterListener())
                .build();
    }

    /**
     * 建立 Jpa Reader
     * 
     * @return
     */
    @Bean("Db001JpaReader")
    public RepositoryItemReader<CarsDto> itemReader() {

        Map<String, Direction> sortMap = new HashMap<>();
        sortMap.put("Manufacturer", Direction.ASC);
        sortMap.put("Type", Direction.ASC);

        return new RepositoryItemReaderBuilder<CarsDto>()
                .name("Db001JpaReader")
                .pageSize(FETCH_SIZE)
                .repository(carRepo)
                .methodName("findAll")
                .sorts(sortMap)
                .build();
    }

    /**
     * 建立 File Writer
     * @return
     */
    @Bean("Db001FileWriter")
    public FlatFileItemWriter<Cars> customFlatFileWriter() {

        String fileName = new SimpleDateFormat("yyyyMMddHHmmssS").format(new Date());

        return new FlatFileItemWriterBuilder<Cars>().name("Db001FileWriter")
                .encoding("UTF-8")
                .resource(new FileSystemResource("D:/" + fileName + ".csv"))
                .append(true)
                .delimited()
                .names(MAPPER_FIELD)
                .headerCallback(headerCallback -> headerCallback.write(HEADER))
                .build();
    }
}
```

## 建立 ItemProcessorListener
跟 Reader 及 Writer 相似，Processor 也有 Listener 可以監控狀態。

```
spring.batch.springBatchExample.batch.job
  |--DbReaderJobConfig.java // 修改
spring.batch.springBatchExample.batch.processor
  |--DBItemProcessor.java
spring.batch.springBatchExample.batch.listener
  |--Db001ProcessorListener.java // 新增
spring.batch.springBatchExample.dto
  |--CarsDto.java
```

* `Db001ProcessorListener.java`
```java
public class Db001ProcessorListener implements ItemProcessListener<Cars, CarsDto>{
    
    private static final Logger LOGGER = LoggerFactory.getLogger(Db001ProcessorListener.class);

    @Override
    public void beforeProcess(Cars item) {
        LOGGER.info("Manufacturer = {}", item.getManufacturer());
        LOGGER.info("Type = {}", item.getType());
        
    }

    @Override
    public void afterProcess(Cars item, CarsDto result) {
        LOGGER.info("Spread = {}", result.getSpread());
        
    }

    @Override
    public void onProcessError(Cars item, Exception e) {
        LOGGER.info("Db001Processor, error item = {}, {}", item.getManufacturer(), item.getType());
        LOGGER.info("errMsg = {}", e.getMessage());
    }
}
```

撰寫完成後一樣在 JobConfig 中加入 Listener。
* `DbReaderJobConfig.java`
```java
...
@Bean("Db001Step")
public Step dbReaderStep(@Qualifier("Db001JpaReader") ItemReader<Cars> itemReader, @Qualifier("Db001FileWriter") ItemWriter<CarsDto> itemWriter,
        ItemProcessor<Cars, CarsDto> processor, JpaTransactionManager transactionManager) {

    return stepBuilderFactory.get("Db001Step")
            .transactionManager(transactionManager)
            .<Cars, CarsDto>chunk(FETCH_SIZE)
            .faultTolerant()
            .skip(Exception.class)
            .skipLimit(Integer.MAX_VALUE)
            .reader(itemReader)
            .processor(processor)
            .writer(itemWriter)
            .listener(new Db001StepListener())
            .listener(new Db001ReaderListener())
            .listener(new Db001ProcessorListener()) // 加入
            .listener(new Db001WriterListener())
            .build();
}
...
```

## 參考
* https://docs.spring.io/spring-batch/docs/current/reference/html/processor.html#itemProcessor
