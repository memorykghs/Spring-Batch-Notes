# 15 - Retry
前面介紹到的 Skip 在 `Chunk-oriented` Step 中可以妥善的處理例外並讓批次繼續進行下去。有個情況，如果在批次中打電文去要資料，有時候會打不通 ( 可能因為網路問題? )，不過通常再試一次就可以了，這樣暫時性的例外是不是可以不要 skip 掉，讓他重新打一次就可以了呢?上述的情況可以使用 Spring Batch 的 `retry` 機制達到目的。

![](/images/15-1.png)

欸，如果是這樣的話不是就可以在每次拋出例外的時候都 retry 呢?

其實不建議這麼做，因為 retry 只會發生在 processing 及 writing 的階段，而且在默認情況下，retry 是會觸發 rollback 的，所以必須小心地使用。太常 retry 也會導致效能變慢，所以 retry 的行為其實應該僅用來處理非確定性的例外。

## 配置 Retry 機制
設定 Retry 機制的方式很簡單，只要在 Step 中加入 `retry()` 方法，設定要 Retry 的 Exception 類別即可。如果有多個 Exception 需要設定，多次使用 `retry()` 方法設定，或是建立 `RetryPolicy`。

```
spring.batch.springBatchExample.batch.job
  |--DbReaderJobConfig.java // 修改
spring.batch.springBatchExample.batch.processor
  |--DBItemProcessor.java // 修改
spring.batch.springBatchExample.exception
  |--ErrorInputException.java
  |--DataNotFoundException.java
```

* `DbReaderJobConfig.java`
```java
...
@Bean("Db001Step")
public Step dbReaderStep(@Qualifier("Db001JpaReader") ItemReader<Cars> itemReader, @Qualifier("Db001FileWriter") ItemWriter<CarsDto> itemWriter,
    ItemProcessor<Cars, CarsDto> processor, JpaTransactionManager transactionManager) {

    return stepBuilderFactory.get("Db001Step")
            .transactionManager(transactionManager)
            .<Cars, CarsDto>chunk(FETCH_SIZE)
            .faultTolerant()
            .skip(Exception.class)
            .skipLimit(Integer.MAX_VALUE)
            .retry(ErrorInputException.class) // 加入
            .retry(DataNotFoundException.class) // 加入
            .retryLimit(1) // 加入
            .reader(itemReader)
            .processor(processor)
            .writer(itemWriter)
            .listener(new Db001StepListener())
            .listener(new Db001ReaderListener())
            .listener(new Db001WriterListener())
            .build();
}
...
```

這邊要稍微注意一下 `retry()` 方法呼叫的位置。下面是 Retry 相關方法的 API。

![](/images/15-2.png)

`retry()` 其實是 `FaultTolerantStepBuilder` 的方法，也就是說跟設定 Skip 邏輯一樣，要先使用 `faultTolerant()` 換成 `FaultTolerantStepBuilder` 才能設定 Retry 機制。

然後修改一下 `ItemProcessor` 中的邏輯，讓它丟出我們設定在 Retry 機制中的 Exception。然後使用 `retryLimit()` 方法設定 Retry 的上限次數 ( 不一定需要設定 )。

* `DBItemProcessor.java`
```java
@Component
public class DBItemProcessor implements ItemProcessor<Cars, CarsDto> {

    @Override
    public CarsDto process(Cars item) throws Exception {

        // 計算每一廠牌汽車底價及售價價差
        CarsDto carsDto = new CarsDto();
        carsDto.setManufacturer(item.getManufacturer());
        carsDto.setType(item.getType());
        carsDto.setSpread(item.getPrice().subtract(item.getMinPrice()));
        
        throw new ErrorInputException(); // 丟出 Exception

        // return carsDto;
    }
}
```

## Retry Policy
當現有的 Retry 機制不符合需求時，就來建立 Retry Policy 吧!


## 參考
* https://www.toptal.com/spring/spring-batch-tutorial
* https://blog.codecentric.de/en/2012/03/transactions-in-spring-batch-part-3-skip-and-retry/
* https://javabeat.net/configure-spring-batch-to-retrying-on-error/
