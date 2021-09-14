# 09 - 建立 ItemWriter、ItemWriterListener 並寫入資料庫
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
以下例子由於需要做依些邏輯處理、並且呼叫多個 Repository 對資料進行異動，所以另外寫了一個 class 實作 ItemWriter 介面。
```java
spring.batch.springBatchPractice.batch.job
spring.batch.springBatchPractice.batch.listener
  |--BCHBORED001JobListener.java
  |--BCHBORED001ReaderListener.java
spring.batch.springBatchPractice.batch.writer
  |--BCHBORED001Writer.java // 新增
spring.batch.springBatchPractice.entity
  |-- // 需要的 entity
spring.batch.springBatchPractice.repository
  |-- // 需要的 repository
```

* `BCHBORED001Writer.java`
```java
/**
 * 建立 ItemWriter
 * @author memorykghs
 */
@Component
public class BCHBORED001ItemWriter implements ItemWriter<BookInfoDto> {

    /** 書籍資料 Repo */
    @Autowired
    private BookInfoRepo bookInfoRepo;

    /** 標籤屬性 Repo */
    @Autowired
    private TagInfoRepo tagInfoRepo;

    /** 作者資訊 Repo */
    @Autowired
    private AuthorInfoRepo authorInfoRepo;

    /** 類別資訊 Repo */
    @Autowired
    private CategoryInfoRepo categoryInfoRepo;

    /** 使用者資訊 Repo */
    @Autowired
    private UserInfoRepo userInfoRepo;

    @Override
    public void write(List<? extends BookInfoDto> items) throws Exception {

        Timestamp now = new Timestamp(System.currentTimeMillis());
        StringBuilder sb = new StringBuilder();

        for (BookInfoDto item : items) {

            // 1. 依使用者名稱查詢ID
            String userName = item.getUpdName();
            UserInfo userInfo = userInfoRepo.findByUserName(userName).orElseThrow(() -> new DataNotFoundException("查無使用者資料"));

            // 2. 比對作者，若無資料則新增
            String authorName = item.getAuthorName();
            AuthorInfo authorInfo = authorInfoRepo.findByAuthorName(authorName).orElse(new AuthorInfo());
            if (authorInfo.getAuthorId() == null) {
                authorInfo.setAuthorName(authorName);
                authorInfo.setUpdId("SYSTEM");
                authorInfo.setUpdTime(now);

                authorInfoRepo.saveAndFlush(authorInfo);
            }

            // 3. 比對資料類別(懸疑、驚悚等)
            String category = item.getCategory();
            CategoryInfo categoryInfo = categoryInfoRepo.findByName(category).orElse(new CategoryInfo());
            if (categoryInfo.getCategoryId() == null) {
                categoryInfo.setName(category);
                categoryInfoRepo.saveAndFlush(categoryInfo);
            }

            // 4. 處理標籤資訊
            List<String> tagList = Arrays.asList(item.getTags().split("#"));
            tagList.stream().forEach(tag -> {
                TagInfo tagInfo = tagInfoRepo.findByName(tag).orElse(new TagInfo());

                if (tagInfo.getTagId() == null) {
                    tagInfo.setName(category);
                    tagInfoRepo.saveAndFlush(tagInfo);
                }

                sb.append(tagInfo.getTagId()).append(';');
            });

            // 5. 寫入BookInfo、BookComment
            BookInfo bookInfo = new BookInfo();

            String comment1 = item.getComment1();
            String comment = comment1 != null ? comment1 : item.getComment2();

            BookComment bookComment = new BookComment();
            bookComment.setBookInfo(bookInfo);
            bookComment.setComments(comment);
            bookComment.setUpdId(userInfo.getUserId());
            bookComment.setUpdTime(now);
            bookComment.setRecommend(Float.valueOf(item.getRecommend()));

            Set<BookComment> bookCommentSet = new HashSet<>();
            bookCommentSet.add(bookComment);

            bookInfo.setBookComments(bookCommentSet);
            bookInfo.setAuthorId(authorInfo.getAuthorId());
            bookInfo.setType("T00001");
            bookInfo.setCategory(categoryInfo.getCategoryId());
            bookInfo.setTag(sb.toString());
            bookInfo.setDescription(item.getDescription());
            bookInfo.setUpdId(userInfo.getUserId());
            bookInfo.setUpdTime(now);

            bookInfoRepo.save(bookInfo);

            sb.setLength(0);
        }
    }
}
```

ItemWriter<> 介面的泛型型別，要設定成輸入的資料型別，也就是透過 ItemReader 或是 ItemProcess 轉換後的資料格式。而如果只是單純的使用 Repo 寫入的話，可以使用匿名類別的方法，直接在 `BCHBORED001JobConfig.java` 建立 Bean 即可，範例如下：
```java
/**
     * 註冊 ItemWriter
     * @param entityManagerFactory
     * @return
     */
    @Bean
    public ItemWriter<BsrResvResidual> insertResidualWriter(EntityManagerFactory entityManagerFactory) {
        return items -> {
            items.stream().forEach(item -> {
                bsrResvResidualRepo.saveAndFlush(item);
            });
        };
    }
```

## 建立 ItemWriterListener
```java
spring.batch.springBatchPractice.batch.job
  |--BCHBORED001JobConfig.java // 修改
spring.batch.springBatchPractice.batch.listener
  |--BCHBORED001JobListener.java
  |--BCHBORED001ReaderListener.java
  |--BCHBORED001WriterListener.java // 新增
spring.batch.springBatchPractice.batch.writer
  |--BCHBORED001Writer.java
spring.batch.springBatchPractice.entity
  |-- // 需要的 entity
spring.batch.springBatchPractice.repository
  |-- // 需要的 repository
```

```java
/**
 * ItemWriter Listener
 * @author memorykghs
 */
public class BCHBORED001WriterListener implements ItemWriteListener<BookInfoDto> {
    
    private static final Logger LOGGER = LoggerFactory.getLogger(BCHBORED001WriterListener.class);

    @Override
    public void beforeWrite(List<? extends BookInfoDto> items) {
        LOGGER.info("寫入資料開始");
    }

    @Override
    public void afterWrite(List<? extends BookInfoDto> items) {
        LOGGER.info("寫入資料結束");
    }

    @Override
    public void onWriteError(Exception ex, List<? extends BookInfoDto> items) {
        LOGGER.error("BCHBORED001: 寫入資料失敗", ex);
    }

}
```

## 參考
* https://docs.spring.io/spring-batch/docs/current/reference/html/index-single.html#itemWriter
* https://www.itread01.com/content/1539261642.html
