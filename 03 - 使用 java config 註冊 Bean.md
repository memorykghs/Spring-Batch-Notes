# 03 - 使用 java config 註冊 Bean

因為要向 Spring 容器中配置 Spring Batch 相關的 Bean，可以寫一個 Config 檔來處理。

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
