# 07 - Java Config 配置與啟動 Job

Spring 3 之後可以用 Java 配置來取代 XML 配置，Spring Batch 2.2.0 之後，Job 也可以使用 Java 配置。Spring Batch 的基本 Java 配置是基於兩個 components：
1. `@EnableBatchProcessing` 標註
2. 兩個 Builder：`JobBuilderFactory` 及 `StepBuilderFactory`

`@EnableBatchProcessing` 會提供建立批次作業的基本環境配置，在基本配置中，除了建立 StepScope 實例外，還提供了一些可以自動裝配的 Bean：
* `JobRepository`：bean name "jobRepository"
* `JobLauncher`：bean name "jobLauncher"
* `JobRegistry`：bean name "jobRegistry"
* `PlatformTransactionManager`：bean name "transactionManager"
* `JobBuilderFactory`：bean name "jobBuilders"
* `StepBuilderFactory`：bean name "stepBuilders"

此配置的核心是 `BatchConfigurer`，預設會提供上面提到的 Bean 的實例，以及執行環境中需要的 `DataSource` 的 Bean。這些建立出來的 Bean 以及數據會被 JpaRepository 持久化。也可以透過實作 `BatchConfigurer` 介面來自定需要的 Bean，通常是繼承 `DefaultBatchConfigurer` 並 override 所需的 getter 即可。例：
```java
@Bean
public BatchConfigurer batchConfigurer(DataSource dataSource) {
	return new DefaultBatchConfigurer(dataSource) {
		@Override
		public PlatformTransactionManager getTransactionManager() {
			return new MyTransactionManager();
		}
	};
}
```

## 配置 JobRepository
其實只要在 Application 上使用 `@EnableBatchProcessing` 就會有預設的 JobRepository，當然 Spring Batch 也有提供客製化 JobRepository 的方法。

## 配置 JobLauncher
當使用 `@EnableBatchProcessing` 標註時，同時也提供了一個默認的 `JobRegistry` 環境。
最常看到時做 `JobLauncher` 介面的物件是 `SimpleJobLauncher`，並且只需要 `JobRepository` 的依賴，例：
```java
...
// This would reside in your BatchConfigurer implementation
@Override
protected JobLauncher createJobLauncher() throws Exception {
	SimpleJobLauncher jobLauncher = new SimpleJobLauncher();
	jobLauncher.setJobRepository(jobRepository);
	jobLauncher.afterPropertiesSet();
	return jobLauncher;
}
...
```

```
spring.batch.springBatchPractice.config // 新增
  |--BatchConfig.java // 新增
```

`BatchConfig.java`
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
        return new GenericApplicationContextFactory(BCHBORED001JobConfig.class);
    }
}
```
首先會先在 `BatchConfig.java` 這個類別上加上 `@EnableBatchProcessing` 註解，讓我們可以運行 Spring Batch。加上註解後，Spring 會自動幫我們產生與 Spring Batch 相關的 Bean，並將這些 Bean 交給 Spring 容器管理。

## 參考
* https://blog.csdn.net/Chris___/article/details/103352103
* https://docs.spring.io/spring-batch/docs/4.3.x/reference/html/job.html#javaConfig
