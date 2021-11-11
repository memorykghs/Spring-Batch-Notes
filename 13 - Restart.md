# 13 - Restart
第一章的時候有提到過 Spring Batch 的異常處理機制大致上可以分為下面 3 種：
* 重啟 ( Restart )
* 跳過 ( Skip )
* 重試 ( Retry )

當 Job 正在運行時，如果出現一些暫時性的問題，如電文打不通，配置 `Retry` 重試就可以解決，但畢竟有些錯誤不是暫時性的，有設置 `Skip` 邏輯的話，Step 終究還是會因為 skip 的次數上限導致 Job 執行失敗。

這時候就可以使用 `Restart` 重啟功能，因為 Spring Batch 框架可以從先前執行失敗的地方開始繼續處理。重啟 ( restart ) 指的是當特定的 `JobInstance` 的 `JobExecution` 存在的情況下，Job 又重新被 launch 的狀況，也就是說，重啟的設定是針對 Job 物件。

下面是一個做漢堡的流程，當其中一個步驟失敗，會從該步驟重新開始。~~因為切番茄不小心切失敗了你也不會從烤麵包重新做起。~~

![](/images/13-1.png)

Spring Batch 如何知道要在哪裡重新啟動 Job?因為每個 Job 執行後，他都會維護 MetaData，就要對 JobRepository 及其他物件持久化。

## 重啟行為的配置
可以分成 Job 或是 Step 的重啟：
| 屬性 | 作用對象 | 型別 | 說明 |
| --- | --- | --- | --- |
| restartble | Job | boolean | 定義 Job 是否可以被重啟，預設為 `false`。
| allow-start-if-complete | Step | boolean | 定義 Step 是不是
| start-limit | Step | Integer | 設定可以被重起的次數，預設值為 `Integer.MAX_VALUE`。

#### 避免 Job 重啟
既然 Job 預設可以被 restart，也可以將 Job 設定為不可重新啟動。只要在使用 `JobBuilderFactory` 建立 Job 時加上 `preventRestart()` 即可。

```java
@Bean
public Job dbReaderJob(@Qualifier("Db001Step") Step step) {
    return jobBuilderFactory.get("Db001Job")
            .preventRestart() // 設定 Job 不可重啟
            .start(step)
            .listener(new Db001JobListener())
            .build();
}
```
<br/>

#### 設定 Step 的重啟
###### Allow restart if Completed
```java
@Bean
public Step step1() {
	return this.stepBuilderFactory.get("step1")
                .<String, String>chunk(10)
                .reader(itemReader())
                .writer(itemWriter())
                .allowStartIfComplete(true) // allow restart
                .build();
}
```

###### 設定重起的次數上限
```java
@Bean
public Step step1() {
	return this.stepBuilderFactory.get("step1")
                .<String, String>chunk(10)
                .reader(itemReader())
                .writer(itemWriter())
                .startLimit(1) // 設定重啟次數上限
                .build();
}
```
<br/>

## 參考
* https://livebook.manning.com/book/spring-batch-in-action/chapter-8/24
* https://dzone.com/articles/spring-batch-restartability
* https://kipalog.com/posts/Spring-Boot-Batch-Restart-Job-Example
* https://terasoluna-batch.github.io/guideline/5.0.1.RELEASE/en/Ch06_ReProcessing.html#Ch06_RerunRestart_HowToUse_Restart
* https://fangjian0423.github.io/2016/11/09/springbatch-retry-skip/
