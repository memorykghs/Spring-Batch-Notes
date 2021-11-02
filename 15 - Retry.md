# 15 - Retry
前面介紹到的 Skip 在 `Chunk-oriented` Step 中可以妥善的處理例外並讓批次繼續進行下去。有個情況，如果在批次中打電文去要資料，有時候會打不通 ( 可能因為網路問題? )，不過通常再試一次就可以了，這樣暫時性的例外是不是可以不要 skip 掉，讓他重新打一次就可以了呢?上述的情況可以使用 Spring Batch 的 `retry` 機制達到目的。

欸，如果是這樣的話不是就可以在每次拋出例外的時候都 retry 呢?

其實不建議這麼做，因為 retry 只會發生在 processing 及 writing 的階段，而且在默認情況下，retry 是會觸發 rollback 的，所以必須小心地使用。太常 retry 也會導致效能變慢，所以 retry 的行為其實應該僅用來處理非確定性的例外。



## 參考
* https://www.toptal.com/spring/spring-batch-tutorial
* https://blog.codecentric.de/en/2012/03/transactions-in-spring-batch-part-3-skip-and-retry/
* https://javabeat.net/configure-spring-batch-to-retrying-on-error/
