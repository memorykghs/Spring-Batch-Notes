# 05 - 建立 Step

Step 物件封裝了批次處理作業的一個獨立的、有順序的階段。在 Step 中可以自行定義及控制實際批次處理所需要的所有訊息，例如如何讀取、如何處理讀取後的資料等等。一個簡單的 Step 也許只需要簡短的程式，而複雜的業務邏輯也可以透過 Step 的架構來進行設計及處理。

一個 Step 中可以包含 ItemReader、ItemProcessor 及 ItemWriter 這三個物件，分別用來讀取資料、對資料進行處理，以及有需要的時候輸出資料，架構如下：
![](/images/5-1.png)

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
