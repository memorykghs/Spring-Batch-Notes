
* `Skip` — A line in the flat file is incorrectly formatted. You don’t want to stop the job execution because of a couple of bad lines: this could mean losing an unknown amount of updates and inserts. You can tell Spring Batch to skip the line that caused the item reader to throw an exception on a formatting error.
<br/>

* `Retry` — Because some products are already in the database, the flat file data is used to update the products (description, price, and so on). Even if the job runs during periods of low activity in the online store, users sometimes access the updated products, causing the database to lock the corresponding rows. The database throws a concurrency exception when the job tries to update a product in a locked row, but retrying the update again a few milliseconds later works. You can configure Spring Batch to retry automatically.
<br/>

* `Restart` — If Spring Batch has to skip more than 10 products because of badly formatted lines, the input file is considered invalid and should go through a validation phase. The job fails as soon as you reach 10 skipped products, as defined in the configuration. An operator will analyze the input file and correct it before restarting the import. Spring Batch can restart the job on the line that caused the failed execution. The work performed by the previous execution isn’t lost.

## 參考
* https://livebook.manning.com/book/spring-batch-in-action/chapter-8/24
* https://dzone.com/articles/spring-batch-restartability
* https://kipalog.com/posts/Spring-Boot-Batch-Restart-Job-Example
* https://terasoluna-batch.github.io/guideline/5.0.1.RELEASE/en/Ch06_ReProcessing.html#Ch06_RerunRestart_HowToUse_Restart
* https://fangjian0423.github.io/2016/11/09/springbatch-retry-skip/
