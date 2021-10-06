# 05 - 建立 ItemReader 與 ReaderListener
ItemReader 顧名思義就是用來讀取資料的，讀取資料的來源大致上可以分為三種：
1. 檔案 ( Flat File )
2. XML
3. 資料庫 ( Database )

其他 ItemReader 類別可參考以下網址：https://docs.spring.io/spring-batch/docs/current/reference/html/appendix.html#itemReadersAppendix

```
spring.batch.springBatchPractice.job
  |--BCH001JobConfig.java // 修改
spring.batch.springBatchPractice.listener 
  |--BCH001JobListener.java
  |--BCH001StepListener.java
```

* `BCH001JobConfig.java`
```java
public class BCH001JobConfig {

    /** JobBuilderFactory */
    @Autowired
    private JobBuilderFactory jobBuilderFactory;

    /** StepBuilderFactory */
    @Autowired
    private StepBuilderFactory stepBuilderFactory;
    
    /** 分批件數 */
    private static final int FETCH_SIZE = 7;

    /**
     * 註冊 job
     * @param step
     * @return
     */
    public Job bch001Job(@Qualifier("BCH001Job")
    Step step) {
        return jobBuilderFactory.get("BCH001Job")
        .start(step)
        .listener(new BCH001JobListener())
        .build();
    }
    
    /**
     * Step Transaction
     * @return
     */
    @Bean
    public JpaTransactionManager jpaTransactionManager() {
        final JpaTransactionManager transactionManager = new JpaTransactionManager();
        return transactionManager;
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
    private Step BCH001Step1(ItemReader<Map<String, Object>> itemReader, BCH001Processor process, JpaTransactionManager jpaTransactionManager) {
        return stepBuilderFactory.get("BCH001Step1")
                .transactionManager(jpaTransactionManager)
                .<Map<String, Object>, BsrResvResidual> chunk(FETCH_SIZE)
                .reader(itemReader)
                .processor(process)
                .faultTolerant()
                .skip(Exception.class)
                .skipLimit(Integer.MAX_VALUE)
                .listener(new BCH001ReaderListener())
                .listener(new BCH001StepListener())
                .build();
    }
    
    /**
     * 註冊 ItemReader
     * @return
     * @throws IOException
     */
    @Bean
    private RepositoryItemReader<Map<String, Object>> itemReader() throws IOException {

        List<LocalDate> args = new ArrayList<>();
        args.add(getDate());

        Map<String, Direction> sortMap = new HashMap<>();
        sortMap.put("RESV_CONF_ID", Direction.ASC);

        return new RepositoryItemReaderBuilder<Map<String, Object>>().name("itemReader")
                .pageSize(FETCH_SIZE).repository(bsrResvConfigRepo)
                .methodName("getAllBranchConfig")
                .arguments(args)
                .sorts(sortMap)
                .build();
    }
    
    /**
     * 取得查詢區間
     * @return
     */
    private LocalDate getDate() {
        return LocalDate.now();
    }

}
```
