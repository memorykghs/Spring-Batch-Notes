# 07 - 建立 FlatFileItemWriter 與 ItemWriterListener

## 建立 ItemWriter
ItemWriter 在功能上與 ItemReader 相似，但具有相反的作用，負責資料的寫出。在 Database 或是 Queue 的情況下，這些操作可能是插入、更新或是發送。較常使用的 ItemWriter 類別有 `FlatFileItemWriter`、`RepositoryItemWriter`、`JdbcBatchItemWriter` 等等。其他 ItemWriter 的類別可以參考 https://docs.spring.io/spring-batch/docs/current/reference/html/appendix.html#itemWritersAppendix。
```java
public interface ItemWriter<T> {

    void write(List<? extends T> items) throws Exception;

}
```

由於這個範例是由資料庫讀取定輸出檔案，所以我們要使用的是 `FlatFileItemWriter`。接下來在 `DbReaderJobConfig.java` 中新增 ItemWriter 相關設定。
```
spring.batch.springBatchExample.job
  |--DbReaderJobConfig.java // 修改
spring.batch.springBatchExample.listener 
  |--Db001obListener.java
  |--Db001StepListener.java
  |--Db001ReaderListener.java // 新增
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
	
	/** Mapper Field */
    private static final String[] MAPPER_FIELD = new String[] { "Manufacturer", "Type", "MinPrice", "Price" };

    /** Header */
    private final String HEADER = new StringBuilder().append("製造商").append(',').append("類別").append(',').append("底價").append(',')
            .append("售價").toString();

	/**
	 * 建立 Job
	 * 
	 * @param step
	 * @return
	 */
	@Bean
	public Job dbReaderJob(@Qualifier("Db001Step") Step step) {
		return jobBuilderFactory.get("Db001Job")
				// .preventRestart()
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
	public Step dbReaderStep(@Qualifier("Db001JpaReader") ItemReader<Cars> itemReader, @Qualifier("Db001FileWriter") ItemWriter<Cars> itemWriter,
			JpaTransactionManager transactionManager) {

		return stepBuilderFactory.get("Db001Step")
				.transactionManager(transactionManager)
				.<Cars, Cars>chunk(FETCH_SIZE)
				.reader(itemReader)
				.faultTolerant()
//                .skip(Exception.class)
//                .skipLimit(Integer.MAX_VALUE)
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
	public RepositoryItemReader<Cars> itemReader() {

		Map<String, Direction> sortMap = new HashMap<>();
		sortMap.put("Manufacturer", Direction.ASC);
		sortMap.put("Type", Direction.ASC);

		return new RepositoryItemReaderBuilder<Cars>()
				.name("Db001JpaReader")
				.pageSize(FETCH_SIZE)
				.repository(carRepo)
				.methodName("findAll")
				// .arguments(args)
				 .sorts(sortMap) // 必要
				.build();
	}

	/**
	 * 建立 File Writer
	 * @return
	 */
	@Bean("Db001FileWriter")
	public FlatFileItemWriter<Cars> customFlatFileWriter() {

        String fileName = new SimpleDateFormat("yyyyMMddHHmmssS").format(new Date());

		BeanWrapperFieldExtractor<Car> fieldExtractor = new BeanWrapperFieldExtractor<>();
		fieldExtractor.setNames(MAPPER_FIELD);

		DelimitedLineAggregator<Car> lineAggreagor = new DelimitedLineAggregator<>();
		lineAggreagor.setFieldExtractor(fieldExtractor);

		return new FlatFileItemWriterBuilder<Cars>().name("Db001FileWriter")
				.encoding("UTF-8")
				.resource(new FileSystemResource("D:/" + fileName + ".csv"))
				.append(true) // 是否串接在同一個檔案後
				.lineAggregator(lineAggreagor)
				.headerCallback(headerCallback -> headerCallback.write(HEADER)) // 使用 headerCallback 寫入表頭
				.build();
	}
}
```

* `encoding()` - 設定輸出檔案編碼
* `resource()` - 指定輸出檔案位置與檔名，傳入 `Resource` 對象
* `append()` - 每一筆輸出的資料是否要接在同一個檔案後，不分割檔案

## 建立 ItemWriterListener
```
spring.batch.springBatchExample.job
  |--DbReaderJobConfig.java // 修改
spring.batch.springBatchExample.listener 
  |--Db001obListener.java
  |--Db001StepListener.java
  |--Db001ReaderListener.java
  |--Db001WriterListener.java
```

* `Db001WriterListener.java`
```java
public class Db001WriterListener implements ItemWriteListener<CarsDto> {
    
    private static final Logger LOGGER = LoggerFactory.getLogger(Db001WriterListener.class);

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
        LOGGER.error("Db001Writer: 寫入資料失敗", ex);
    }

}
```

## 參考
* https://blog.csdn.net/weixin_38004638/article/details/104765005