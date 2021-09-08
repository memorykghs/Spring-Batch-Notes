# 07 - 讀取 csv 檔
上一章提到 Spring Batch 的讀取資料來源大致上可以分為三種，下面的將以讀取 csv 檔為例。最常用的讀取檔案的 ItemReader 是 FlatFileItemReader。FlatFile 是**扁平結構檔案** ( 也稱為矩陣結構檔案 )，是最常見的一種檔案型別。讀取時通常以一行 ( line ) 為一個單位，同一行資料的欄位支間可以用某種方式切割，例如常見的分號 `;`、逗號 `,`，或是索引 ( index ) 等等。與一般的 JSON、XML 檔案的差別在於他沒有一個特定的結構，所以在讀取的時候需要定義讀取及轉換的規則。

## 建立 FlatFileItemReader
Spring Batch 為檔案讀取提供了 FlatFileItemReader 類別，並提供一些方法用來讀取資料和轉換。在 FlatFileItemReader 中有2個主要的功能介面：Resource 及 LineMapper。 Resource 用於外部檔案讀取，例如：

```java
Resource resource = new FileSystemResource("resources/書單.csv"); 
```

那麼接下來，先建立一個 FlatFileItemReader。
```
spring.batch.springBatchPractice.job
  |--BCHBORED001JobConfig.java // 修改
spring.batch.springBatchPractice.listener
  |--BCHBORED001JobListener.java
  |--BCHBORED001ReaderListener.java // 新增
```
<br/>

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
在 `getItemReader()` 方法中，使用 FlatFileItemReaderBuilder 來建立我們要的 FlatFileItemReade，並透過 `name()` 方法來為 FlatFileItemReader 實例命名。

#### FlatFileItemReader 部分屬性
| 方法名稱 | 說明 |
|-- |-- |
| `resource()` | 指定外部資源檔按位置。 |
| `linesToSkip()` | 可以設定要跳過不讀取的行數。 |
| `lineMapper()` | 指定檔案讀取及轉換的規則。 |
| `comments()` | 若檔案中有註解，可以指定註解字首，並過濾內容。 |
| `encoding()` | 指定檔案編碼格式，預設為 `Charset.defaultCharset()`。 |
| `skippedLinesCallback()` | 當有設定 `linesToSkip` 時，當執行時每跳過一行，可傳入被跳過的內容並執行指定方法。 |

再來，要使用 LineMapper 物件來設定檔按欄位的分割以及轉換的規則。

## LineMapper
LineMapper 這個介面的功能是將字串轉換為物件。主要是將讀入的一行資料進行轉換，再轉換的過程中 LineMapper 實例會呼叫 `mapLine()` 方法來處理資料轉換。

```java
public interface LineMapper<T> {

	/**
	 * Implementations must implement this method to map the provided line to 
	 * the parameter type T.  The line number represents the number of lines
	 * into a file the current line resides.
	 * 
	 * @param line to be mapped
	 * @param lineNumber of the current line
	 * @return mapped object of type T
	 * @throws Exception if error occurred while parsing.
	 */
	T mapLine(String line, int lineNumber) throws Exception;
}
```
因為涉及到資料轉換，要從一行 ( line ) 轉換為一個 FieldSet ( 像是 ResultSet 的概念 )，一個欄位是一個 column，必須傳入兩個介面的物件實例給 LineMapper，分別是 **LineTokenizer** 及 **FieldSetMapper**。

#### LineTokenizer
此介面功能主要是用來將一行資料分割為不同的資料欄位 ( FieldSet )，所以在使用 LineMapper 時也要實作此介面。LineTokenizer 介面可以由以下三種類別實現：<br/>

1. DelimitedLineTokenizer：利用分隔符號將資料轉換為 FieldSet，預設為逗號，也可以自行定義分隔符號。
<br/>
2. FixedLengthTokenizer：根據欄位的長度來解析出 FieldSet 結構，所以必須為記錄且定義欄位寬度。
<br/>
3. PatternMatchingCompositeLineTokenizer：自訂匹配機制來動態決定要使用哪一種 LineTokenizer。

在此範例中，使用 DelimitedLineTokenizer 實例。

```java
// 1. 設定每一筆資料的欄位拆分規則，預設以逗號拆分
DelimitedLineTokenizer tokenizer = new DelimitedLineTokenizer();
tokenizer.setNames(MAPPER_FIELD);
```

#### FieldSetMapper
FieldSetMapper 介面是將讀入併分割好的 FieldSet 轉換為程式面的物件；

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
