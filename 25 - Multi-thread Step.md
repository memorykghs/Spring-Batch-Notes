# 25 - Multi-thread Step
## Scaling and Parallel Processing
Spring Batch 在平行處理 ( parallel processing ) 兩種模式：
* 單線程、多執行緒 ( single process, multi-thread )
* 多進程 ( multi-process )

這些又可以再細分為幾類，如下所示：
* Multi-threaded Step ( 單線程 )
* Parallel Steps ( 單線程 )
* Remote Chunking of Step ( 多線程 )
* Partitioning a Step ( 單線程或多線程 )

這個章節主要會關注在多執行緒的 Step 上。

## Multi-threaded Step ( 多執行緒 Step )
在 Step 中發 Request 到其他 API 並對回傳的資料進行處理，打 API 的過程如果一筆一筆資料打的話，可能會花不少時間，這時候就可以使用多執行緒的 Step 來幫助我們在較短的時間內拿到所有想要的資料。

不過在 Spring Batch 框架中，提供的大部分 ItemReader 及 ItemWriter 都不是 thread-safe 的，在處理的時候要特別注意確保執行緒安全。因為在 Step 處理過程中，Readers 跟 Writers 是有狀態的，如果狀態並非被不同的執行緒隔離而是互相影響的話，狀態內保留的資訊就沒有用處了。

![](/images/icon-bird-2.png) 不過 Spring Batch 框架也可以使用 stateless 且執行緒安全的 Readers 或 Writers，需要的話可以試試 `parallelJob`。

## 使用多執行緒 Step
```
spring.batch.springBatchExample.job
  |--dbReaderJobConfig.java // 修改
```

```java
public Step dbReaderStep(ItemReader<Cars> itemReader, ItemWriter<CarsDto> itemWriter, ItemProcessor<Cars, CarsDto> processor, JpaTransactionManager transactionManager) {

    return stepBuilderFactory.get("Db001Step")
            .transactionManager(transactionManager)
            .<Cars, CarsDto>chunk(FETCH_SIZE)
            .faultTolerant()
            .skip(Exception.class)
            .skipLimit(Integer.MAX_VALUE)
            .reader(itemReader)
            .processor(processor)
            .writer(itemWriter)
            .taskExecutor(new SimpleAsyncTaskExecutor()) // 新增非同步 Step
            .throttleLimit(5) // 設定持行緒 pool 最大數量
            .listener(new Db001StepListener())
            .listener(new Db001ReaderListener())
            .listener(new Db001WriterListener())
            .build();
}
```
在 Step 中使用 `taskExecutor()` 就可以觸發多執行緒的 Step，傳入參數必須是實作 `TaskExecutor` 介面的物件。框架中預設有提供以下 5 種不同的 `TaskExecutor` 實作類別。這邊選用最基本的 `SimpleAsyncTaskExecutor`。

| Class | 說明 | 是否非同步 |
| --- | --- | :---: |
| `SyncTaskExecutor` | 簡單的同步執行器 | 否 |
| `ThrottledTaskExecutor` | 该执行器为其他任意执行器的装饰类，并完成提供执行次数限制的功能 | 视被装饰的执行器而定
| `SimpleAsyncTaskExecutor` | 最基本的非同步簡單執行器 | 是
| `WorkManagerTaskExecutor` | 该类作为通过 JCA 规范进行任务执行的实现，其包含 JBossWorkManagerTaskExecutor 和 GlassFishWorkManagerTaskExecutor 两个子类 | 是
| `ThreadPoolTaskExecutor` | 线程池任务执行器 | 是

再來可以對執行緒 pool 進行設定，使用 `throttleLimit()` 就可以針對執行緒數量的上限進行限制。

## 如何確保執行緒安全?
對 ItemReader 或是 ItemWriter 使用 synchronized 的類別，例如 ItemWriter 就有 `SynchronizedItemStreamWriterBuilder` 類別可以使用。

```
spring.batch.springBatchExample.job
  |--dbReaderJobConfig.java // 修改
```

首先建立執行緒安全的 ItemWriter： 
```java
@Bean("SynchronizedWriter")
public SynchronizedItemStreamWriter<CarsDto> getSynchronizedItemStreamWriter(FlatFileItemWriter<CarsDto> itemWriter){
    return new SynchronizedItemStreamWriterBuilder<CarsDto>()
            .delegate(itemWriter)
            .build();
            
}
```
`delegate()` 方法中代表的是實際要進行寫入動作的 ItemWriter，傳入的類別必須實作 `ItemStreamWriter` 介面。
```java
public SynchronizedItemStreamWriterBuilder<T> delegate(ItemStreamWriter<T> delegate) {
    this.delegate = delegate;

    return this;
}
```

再來，替換掉設定 Step 中 ItemWriter 的部分即可。
```java
public Step dbReaderStep(ItemReader<Cars> itemReader, SynchronizedItemStreamWriter<CarsDto> itemWriter,
				ItemProcessor<Cars, CarsDto> processor, JpaTransactionManager transactionManager) {

    return stepBuilderFactory.get("Db001Step")
            .transactionManager(transactionManager)
            .<Cars, CarsDto>chunk(FETCH_SIZE)
            .faultTolerant()
            .skip(Exception.class)
            .skipLimit(Integer.MAX_VALUE)
            .reader(itemReader)
            .processor(processor)
            .writer(itemWriter)
            .taskExecutor(new SimpleAsyncTaskExecutor())
            .throttleLimit(5)
            .listener(new Db001StepListener())
            .listener(new Db001ReaderListener())
            .listener(new Db001WriterListener())
            .build();
}
```


## 參考
* https://docs.spring.io/spring-batch/docs/current/reference/html/scalability.html#scalabilityParallelSteps
* https://blog.csdn.net/u010105645/article/details/109560768
* https://blog.csdn.net/w372426096/article/details/78433883