# 07 - 讀取 csv 檔
上一章提到 Spring Batch 的讀取資料來源大致上可以分為三種，下面的將以讀取 csv 檔為例。最常用的讀取檔案的 ItemReader 是 FlatFileItemReader。FlatFile 是**扁平結構檔案** ( 也稱為矩陣結構檔案 )，是最常見的一種檔案型別。讀取時通常以一行 ( line ) 為一個單位，同一行資料的欄位支間可以用某種方式切割，例如常見的分號 `;`、逗號 `,`，或是索引 ( index ) 等等。與一般的 JSON、XML 檔案的差別在於他沒有一個特定的結構，所以在讀取的時候需要定義讀取及轉換的規則。

## 建立 FlatFileItemReader
首先建立一個 FlatFileItemReader。
```
spring.batch.springBatchPractice.job
  |--BCHBORED001JobConfig.java // 修改
spring.batch.springBatchPractice.listener
  |--BCHBORED001JobListener.java
  |--BCHBORED001ReaderListener.java // 新增
```

* `BCHBORED001JobConfig.java`
```java
public class BCHBORED001JobConfig {

  /** JobBuilderFactory */
  @Autowired
  private JobBuilderFactory jobBuilderFactory;

  /** StepBuilderFactory */
  @Autowired
  private StepBuilderFactory stepBuilderFactory;

  /** 每批件數 */
  private static final int FETCH_SIZE = 10;

  @Bean
  public Job fileReaderJob(@Qualifier("fileReaderJob") Step step) {
      return jobBuilderFactory.get("fileReaderJob")
              .start(step)
              .listener(null)
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
  @Bean("fileReaderStep")
  private Step fileReaderStep(ItemReader<BookInfoDto> itemReader, BCH001Processor process, ItemWriter<BsrResvResidual> itemWriter,
          JpaTransactionManager jpaTransactionManager) {
      return stepBuilderFactory.get("BCH001Step1")
              .transactionManager(jpaTransactionManager)
              .<BookInfoDto, BsrResvResidual> chunk(FETCH_SIZE)
              .reader(itemReader)
              .processor(process) 
              .faultTolerant()
              .skip(Exception.class)
              .skipLimit(Integer.MAX_VALUE)
              .writer(itemWriter)
              .listener(new BCHBORED001StepListener())
              .listener(new BCHBORED001ReaderListener())
              .build();
  }

  /**
   * 建立 FileReader
   * @return
   */
  @Bean
  public ItemReader<BookInfoDto> getItemReader() {
      return new FlatFileItemReaderBuilder<BookInfoDto>().name("fileReader")
              .resource(new ClassPathResource("/excel/書單.csv"))
              .linesToSkip(1)
              .lineMapper(getBookInfoLineMapper())
              .build();
  }
}
```
在 `getItemReader()` 方法中，使用 FlatFileItemReaderBuilder 來建立我們要的 FlatFileItemReader。
* `name()` - 為 FlatFileItemReader 實例命名。
* `linesToSkip()` - 可以設定要跳過不讀取的行數。
* `lineMapper()` - 指定檔案讀取及轉換的規則。

再來，要使用 LineMapper 物件來設定檔按欄位的分割以及轉換的規則。

## LineMapper


如果不指定欄位名稱，依照被逗號分隔後的 `fieldSet` 位置來進行 mapping，方法如下：
```java
private LineMapper<BookInfoDto> getBookInfoLineMapper() {
  DefaultLineMapper<BookInfoDto> bookInfoLineMapper = new DefaultLineMapper<>();

  // 1. 設定每一筆資料的欄位拆分規則
  DelimitedLineTokenizer tokenizer = new DelimitedLineTokenizer();

  // 2. 指定 fieldSet 對應邏輯
  FieldSetMapper<BookInfoDto> fieldSetMapper = fieldSet -> {
    BookInfoDto bookInfDto = new BookInfoDto();
    bookInfDto.setBookName(fieldSet.readString(0));
    bookInfDto.setAuthor(fieldSet.readString(1));
    bookInfDto.setCategory(fieldSet.readString(2));
    bookInfDto.setTags(fieldSet.readString(3));
    bookInfDto.setRecommend(fieldSet.readString(4));
    bookInfDto.setDescription(fieldSet.readString(5));
    bookInfDto.setComment1(fieldSet.readString(6));
    bookInfDto.setComment2(fieldSet.readString(7));
    bookInfDto.setUpdDate(fieldSet.readString(8));
    bookInfDto.setUpdName(fieldSet.readString(9));

    return bookInfDto;
  };

  bookInfoLineMapper.setLineTokenizer(tokenizer);
  bookInfoLineMapper.setFieldSetMapper(fieldSetMapper);
  return bookInfoLineMapper;
}
```
 DelimitedLineTokenizer 預設的分隔符號是逗號 `,`，所以不需要特別做設定。

## 參考
* https://stackoverflow.com/questions/66234905/reading-csv-data-in-spring-batch-creating-a-custom-linemapper
* https://www.itread01.com/content/1562677203.html
