# 09 - Restart
第一章的時候有提到過 Spring Batch 的異常處理機制大致上可以分為下面 3 種：
* 跳過
* 重試
* 重啟

重啟 ( restart ) 指的是當特定的 `JobInstance` 的 `JobExecution` 存在的情況下，Job 又重新被 launch 的狀況，也就是說，重啟的設定是針對 Job 物件。Spring Batch 中的 Job 預設都可以在其原本失敗的地方被重啟，繼續往下執行 ( 當然也有例外 )。

既然 Job 預設可以被 restart，也可以將 Job 設定為不可重新啟動。只要在使用 `JobBuilderFactory` 建立 Job 時加上 `preventRestart()` 即可。



* `Retry` — Because some products are already in the database, the flat file data is used to update the products (description, price, and so on). Even if the job runs during periods of low activity in the online store, users sometimes access the updated products, causing the database to lock the corresponding rows. The database throws a concurrency exception when the job tries to update a product in a locked row, but retrying the update again a few milliseconds later works. You can configure Spring Batch to retry automatically.
<br/>

* `Restart` — If Spring Batch has to skip more than 10 products because of badly formatted lines, the input file is considered invalid and should go through a validation phase. The job fails as soon as you reach 10 skipped products, as defined in the configuration. An operator will analyze the input file and correct it before restarting the import. Spring Batch can restart the job on the line that caused the failed execution. The work performed by the previous execution isn’t lost.


## 參考
* https://livebook.manning.com/book/spring-batch-in-action/chapter-8/24
* https://dzone.com/articles/spring-batch-restartability
* https://kipalog.com/posts/Spring-Boot-Batch-Restart-Job-Example
* https://terasoluna-batch.github.io/guideline/5.0.1.RELEASE/en/Ch06_ReProcessing.html#Ch06_RerunRestart_HowToUse_Restart
* https://fangjian0423.github.io/2016/11/09/springbatch-retry-skip/
