# 11 - 建立 Tasklet
前面提到的 **Chunk-oriented process** 並非是 Step 中唯一種處理模式，通常會這樣處理資料是因為來源數據可能非常龐大，且需要做一些業務邏輯處理，透過資料的分批與聚合，將這些動作拆分且有效率的達到目的。

不過當今天 Step 中只要做一件簡單的事情，例如刪除資料，沒有讀取也沒有輸出的話，依照前面介紹的 Chunk-oriented 的模式，會需要建立一個 ItemReader 並在處理結束時回傳 `null`，再建立一個不做任何事情的 ItemWriter，可是這樣的動作顯得有些多此一舉，畢竟我就只是想要刪除資料而已為什麼需要這麼麻煩!?<br/>

<font color="red">Reader 回傳 null 應該就不會進到 Writer 了。</font>

![](/images/傷腦筋.png)

所以 Spring Batch 框架額外提供了 `TaskletStep` 來處理類似的情況。

## Tasklet
`Tasklet` 是一個介面，並提供一個 `execute()` 方法，該方法最後會回傳執行結果： `RepeatStatus.FINISHED` 或丟出例外 ( 代表執行失敗 )。實作這個介面的物件會被 `TaskletStep` 呼叫，代表其實我們還是需要建立一個 Step，並在 Step 中使用 `tasklet()` 設定要執行的 `Tasklet`。

由於 `Tasklet` 中可能會使用 stored procedure、script 或是簡單的 SQL 對資料進行異動，因此當 `Tasklet` 被呼叫執行過程，都會有 Transaction。<br/>

![](/images/11-1.png)

## 建立 Tasklet
由於這個 Tasklet 主要是要清除批次相關 Table 的資料，且可以透過傳入的參數指定要刪掉幾個月前的，所以先在 `application.properties` 內設定一個預設值。

```
src/main/resources
  |--application.properties // 修改
src/main/java
  |--spring.batch.springBatchExample
    |--SpringBatchExmapleApplication.java // 修改
  |--spring.batch.springBatchExample.job
    |--DbReaderJobConfig.java // 修改
  |--spring.batch.springBatchExample.tasklet 
    |--ClearLogTasklet.java // 新增
```

* `application.properties`
```properties
# default clear batch log month range
defaultMonth=12
```
此為預設刪除的月份數，等於一次刪掉一年的量。
<br/>

然後我們想要在啟動的時候判斷執行的 Job 名稱如果是清除 Log 的話，可以依照傳入指定要刪除的月份區間，例如給定 1 就是刪除從今天回推一個月之前，跟批次相關的 6 張表內容都要清除。

* `SpringBatchExmapleApplication.java`
```java
@SpringBootApplication
@EnableBatchProcessing
public class SpringBatchExmapleApplication {

    private static final Logger LOGGER = LoggerFactory.getLogger(SpringBatchExmapleApplication.class);

    public static void main(String[] args) throws NoSuchJobException, JobExecutionAlreadyRunningException,
        JobRestartException, JobInstanceAlreadyCompleteException, JobParametersInvalidException {

        args = new String[] {"Db001Job", "1"}; // 新增

        try {
            String jobName = args[0];

            ConfigurableApplicationContext context = SpringApplication.run(SpringBatchExmapleApplication.class, args);
            Job job = context.getBean(JobRegistry.class).getJob(jobName);
            context.getBean(JobLauncher.class).run(job, createJobParams());

        } catch (Exception e) {
            LOGGER.error("springBatchPractice執行失敗", e);
        }
    }

    /**
     * 產生JobParameter
     * @return
     */
    private static JobParameters createJobParams() {

        JobParametersBuilder builder = new JobParametersBuilder();
        builder.addDate("executeTime", Timestamp.valueOf(LocalDateTime.now()));

        if ("Db001Job".equals(jobName)) { // 新增判斷邏輯
            if(args.length > 1) {
                builder.addString("clsMonth", args[1]);
            }
        }

        return builder.toJobParameters();
    }
}
```

接下來就來建立一個定期清除資料庫中批次 Log 的 Tasklet 吧!下面的程式碼看起來很長，不過實際上就只是要先查出 `JOB_EXECUTION_ID`，再依照取得的 `JOB_EXECUTION_ID` 去搜尋 `JOB_INSTANCE_ID` 及 `STEP_EXECUTION_ID`。

* `ClearLogTasklet.java`
```java
@StepScope
@Component
public class ClearLogTasklet implements Tasklet, StepExecutionListener {
    /** LOGGER */
    private static final Logger LOGGER = LoggerFactory.getLogger(ClearLogDataTasklet.class);

    /** 指令傳入之刪除月份範圍 */
    @Value("#{jobParameters['clsMonth']}")
    private String clsMonth;

    /** 預設刪除區間 */
    @Value("${defaultMonth}")
    private String defaultMonth;

    /** 查詢符合n個月前紀錄的 JobExecution Id，n預設為12 */
    private static final String SQL_QUERY_JOB_EXECUTION_ID = "select BATCH_JOB_EXECUTION.JOB_EXECUTION_ID from OTRLXFXS01.BATCH_JOB_EXECUTION"
            + " where BATCH_JOB_EXECUTION.CREATE_TIME < :clearDate";

    /** 依 Execution Id 查詢對應 JobInstance Id */
    private static final String SQL_QUERY_JOB_INSTANCE_ID = "select BATCH_JOB_INSTANCE.JOB_INSTANCE_ID"
            + " from OTRLXFXS01.BATCH_JOB_INSTANCE"
            + " join OTRLXFXS01.BATCH_JOB_EXECUTION on BATCH_JOB_EXECUTION.JOB_INSTANCE_ID = BATCH_JOB_INSTANCE.JOB_INSTANCE_ID"
            + " where BATCH_JOB_EXECUTION.JOB_EXECUTION_ID in (:jobExecutionIdList)";

    /** 依 Execution Id 查詢對應 StepExecution Id */
    private static final String SQL_QUERY_STEP_EXECUTION_ID = "select BATCH_STEP_EXECUTION.STEP_EXECUTION_ID"
            + " from OTRLXFXS01.BATCH_STEP_EXECUTION"
            + " join OTRLXFXS01.BATCH_JOB_EXECUTION on BATCH_JOB_EXECUTION.JOB_EXECUTION_ID = BATCH_STEP_EXECUTION.JOB_EXECUTION_ID"
            + " where BATCH_JOB_EXECUTION.JOB_EXECUTION_ID in (:jobExecutionIdList)";

    /** 刪除 STEP_EXECUTION_CONTEXT */
    private static final String SQL_DELETE_BATCH_STEP_EXECUTION_CONTEXT = "delete from OTRLXFXS01.BATCH_STEP_EXECUTION_CONTEXT where STEP_EXECUTION_ID in (:stepExecutionIdList)";

    /** 刪除 JOB_EXECUTION_CONTEXT */
    private static final String SQL_DELETE_BATCH_JOB_EXECUTION_CONTEXT = "delete from OTRLXFXS01.BATCH_JOB_EXECUTION_CONTEXT where JOB_EXECUTION_ID in (:jobExecutionIdList)";

    /** 刪除 STEP_EXECUTION */
    private static final String SQL_DELETE_BATCH_STEP_EXECUTION = "delete from OTRLXFXS01.BATCH_STEP_EXECUTION where STEP_EXECUTION_ID in (:stepExecutionIdList)";

    /** 刪除 BATCH_JOB_EXECUTION_PARAMS */
    private static final String SQL_DELETE_BATCH_JOB_EXECUTION_PARAMS = "delete from OTRLXFXS01.BATCH_JOB_EXECUTION_PARAMS where JOB_EXECUTION_ID in (:jobExecutionIdList)";

    /** 刪除 JOB_EXECUTION */
    private static final String SQL_DELETE_BATCH_JOB_EXECUTION = "delete from OTRLXFXS01.BATCH_JOB_EXECUTION where CREATE_TIME < :clearDate";

    /** 刪除 BATCH_JOB_INSTANCE */
    private static final String SQL_DELETE_BATCH_JOB_INSTANCE = "delete from OTRLXFXS01.BATCH_JOB_INSTANCE where JOB_INSTANCE_ID in (:jobInstanceIdList)";

    /** jdbcTemplate */
    @Autowired
    private NamedParameterJdbcTemplate jdbcTemplate;

    @Override
    public void beforeStep(StepExecution stepExecution) {
        LOGGER.info("清除資料庫Log開始");
    }

    @Override
    public ExitStatus afterStep(StepExecution stepExecution) {
        LOGGER.info("清除資料庫Log結束");
        return null;
    }

    @Override
    public RepeatStatus execute(StepContribution contribution, ChunkContext chunkContext) throws Exception {

        int totalCount = 0;

        LocalDate clearDate = LocalDate.now();

        if (StringUtils.isNotBlank(clsMonth)) {
            clearDate = clearDate.minusMonths(Long.parseLong(clsMonth));
        }else {
            clearDate = clearDate.minusMonths(Long.parseLong(defaultMonth));
        }

        LOGGER.info("清除{}之前Spring Batch history log", clearDate);

        Map<String, Object> paramsMap = new HashMap<>();
        paramsMap.put("clearDate", Timestamp.valueOf(clearDate.atStartOfDay()));

        // get JOB_EXECUTION_ID
        List<BigDecimal> jobExecutionIdList = jdbcTemplate.queryForList(SQL_QUERY_JOB_EXECUTION_ID, paramsMap).stream()
                .map(map -> (BigDecimal) map.get("JOB_EXECUTION_ID")).collect(Collectors.toList());
        if (jobExecutionIdList.isEmpty()) {
            LOGGER.info("該日期以前無EXECUTION_ID資料");
            return RepeatStatus.FINISHED;
        }

        // get STEP_EXECUTION_ID
        paramsMap.put("jobExecutionIdList", jobExecutionIdList);
        List<BigDecimal> stepExecutionIdList = jdbcTemplate.queryForList(SQL_QUERY_STEP_EXECUTION_ID, paramsMap).stream()
                .map(map -> (BigDecimal) map.get("STEP_EXECUTION_ID")).collect(Collectors.toList());

        // get JOB_INSTANCE_ID
        List<BigDecimal> jobInstanceIdList = jdbcTemplate.queryForList(SQL_QUERY_JOB_INSTANCE_ID, paramsMap).stream()
                .map(map -> (BigDecimal) map.get("JOB_INSTANCE_ID")).collect(Collectors.toList());

        // 1. clear BATCH_STEP_EXECUTION_CONTEXT
        paramsMap.put("stepExecutionIdList", stepExecutionIdList);
        int rowCount = jdbcTemplate.update(SQL_DELETE_BATCH_STEP_EXECUTION_CONTEXT, paramsMap);
        LOGGER.debug("BATCH_STEP_EXECUTION_CONTEXT count: {}", rowCount);
        totalCount += rowCount;

        // 2. clear BATCH_JOB_EXECUTION_CONTEXT
        rowCount = jdbcTemplate.update(SQL_DELETE_BATCH_JOB_EXECUTION_CONTEXT, paramsMap);
        LOGGER.debug("JOB_EXECUTION_CONTEXT count: {}", rowCount);
        totalCount += rowCount;

        // 3. clear BATCH_STEP_EXECUTION
        rowCount = jdbcTemplate.update(SQL_DELETE_BATCH_STEP_EXECUTION, paramsMap);
        LOGGER.debug("BATCH_STEP_EXECUTION count: {}", rowCount);
        totalCount += rowCount;

        // 4. clear BATCH_JOB_EXECUTION_PARAMS
        rowCount = jdbcTemplate.update(SQL_DELETE_BATCH_JOB_EXECUTION_PARAMS, paramsMap);
        LOGGER.debug("JOB_EXECUTION_PARAMS count: {}", rowCount);
        totalCount += rowCount;

        // 5. clear BATCH_JOB_EXECUTION
        rowCount = jdbcTemplate.update(SQL_DELETE_BATCH_JOB_EXECUTION, paramsMap);
        LOGGER.debug("BATCH_JOB_EXECUTION count: {}", rowCount);
        totalCount += rowCount;

        // 6. clear BATCH_JOB_INSTANCE
        paramsMap.put("jobInstanceIdList", jobInstanceIdList);
        rowCount = jdbcTemplate.update(SQL_DELETE_BATCH_JOB_INSTANCE, paramsMap);
        LOGGER.debug("BATCH_JOB_INSTANCE count: {}", rowCount);
        totalCount += rowCount;

        contribution.incrementWriteCount(totalCount);

        return RepeatStatus.FINISHED;
    }
}
```
由於只有一個 `Tasklet`，所以 Listener 的部分就一起實作，寫在同一個 class 裡面。刪除的部分看起來很多，因為 Batch 的 Log 每張表之間是有關連的，所以必須依照順序進行刪除......

另外在宣告屬性的地方，有兩行：
```java
/** 指令傳入之刪除月份範圍 */
@Value("#{jobParameters['clsMonth']}")
private String clsMonth;

/** 預設刪除區間 */
@Value("${defaultMonth}")
private String defaultMonth;
```

前幾章提到 `JobParameter` 可以在執行時期 ( run time ) 取得，取得的方式就是使用在屬性上使用 `@Value` 標籤，用 `#` 指定取得的執行環境。`$` 則是取得設定檔的參數。
<br/>

建立完 `Tasklet` 後，回到 `DbReaderJobConfig.java` 中新增一個 Step，並注入剛剛撰寫的 `Tasklet`。
* `ClearLogJobConfig.java`
```java
...
@Bean
public Job dbReaderJob(@Qualifier("clearLogStep") Step step) {
    return jobBuilderFactory.get("Db001Job")
        .start(step)
        .listener(new Db001JobListener())
        .build();
}

@Bean("clearLogStep")
public Step clearLogStep(JpaTransactionManager transactionManager, ClearLogDataTasklet clearLogDataTasklet) {

    return stepBuilderFactory.get("Db001Step")
        .transactionManager(transactionManager)
        .tasklet(clearLogDataTasklet) // 加入 Tasklet
        .build();
}
...
```
<br/>

## 小結
稍微比較一下 `Chunk` 及 `Tasklet` 的差異：

| | Tasklet | Chunk |
| --- | --- | --- |
| When | 當 Job 只需要執行單粒度處理的情況。 | 當要執行的作業很複雜，並涉及讀取、處理或寫入時的情況。 |
| How | 沒有拆分或聚合，只有單一的處理。 | 涉及讀取及根據業務邏輯對資料進行處理後，將資料聚合直到達到提交間隔，最後將要輸出的資料塊寫到文件或資料庫中。
| Usage | 較少使用 | 較常見的批次處理模式 |

## 參考
* https://docs.spring.io/spring-batch/docs/current/reference/html/step.html#taskletStep
* https://www.javainuse.com/spring/batchtaskchunk
* https://www.chkui.com/article/spring/spring_core_resources_management 

###### 梗圖來源
* [傷腦筋](https://kknews.cc/news/r92zxov.html)
