# 05 - 建立 Step

```java
spring.batch.exapmle.job
  |--BCH001JobConfig.java 
spring.batch.exapmle.listener // 新增
  |--BCH001JobListener.java // 新增
```

```java
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

## 參考
* https://medium.com/@softjobdays/springbatch%E7%B0%A1%E4%BB%8B-1b3ef3b8d73e 
* https://docs.spring.io/spring-batch/docs/4.2.x/reference/html/step.html#configureStep
