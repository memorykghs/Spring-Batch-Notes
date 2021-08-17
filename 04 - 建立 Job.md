# 04 - 建立 Job
首先建立一個設定 Job 的 class `BCH001JobConfig`，在這個檔案裡面我們會注入 `JobBuilderFactory` 來建立 Job。Job 本身是一個 interface，實作 Job 的實體類別有像是 `AbstractJob`、`FlowJob`、`GroupAwareJob`、`JsrFlowJob` 以及 `SimpleJob`......等等。而 `JobBuilderFactory` 是基於 Builder Design Pattern 概念設計的，所以在建立 Job 的過程中可以一直串接方法，直到最後用 `build()` 結尾。
由於最終是要對 spring 容器注入設定好的 Job，在 `BCH001JobConfig.java` 內會以方法搭配 `@Bean` 來產生 Job。

```
spring.batch.exapmle.job // 新增
  |--BCH001JobConfig.java // 新增
```
`BCH001JobConfig.java`
```java
public class BCH001JobConfig {
  
  /** JobBuilderFactory */
  @Autowired
  private JobBuilderFactory jobBuilderFactory;
  
  // 要引入的 Repo
  
 
  public Job bch001Job(){
  
  }
}
```

Creates a job builder and initializes its job repository. Note that if the builder is used to create a &#64;Bean
definition then the name of the job and the bean name might be different.

```java
@Configuration
@EnableBatchProcessing(modular = true)
public class BatchConfig extends DefaultBatchConfigurer {
    
    @Override
    public void setDataSource(DataSource dataSource) {
        // 讓Spring Batch自動產生的table不寫入DB
    }
       
    @Bean
    public ApplicationContextFactory getJobContext() {
        // return new GenericApplicationContextFactory(BCHTXMSG001JobConfig.class);
        return new GenericApplicationContextFactory(BCH001obConfig.class, BCH002obConfig.class);
    }
}
```

## 參考
* https://www.toptal.com/spring/spring-batch-tutorial
* https://www.javadevjournal.com/spring-batch/spring-batch-job-configuration/
