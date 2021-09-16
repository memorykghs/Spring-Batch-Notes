# 01 - Spring Batch 簡介
SpringBatch 是由 SpringSource 和 Accenture ( 埃森哲 ) 合作開發的，可以用來資料抽取、資料庫遷移、資料同步等。Spring Batch 只專注於處理邏輯的抽象，跟排程框架是兩回事。可以結合開源的排程框架有 quartz、cron 等等。下圖是 Spring Batch 的分層架構，有較高的多樣化性與可擴展性：<br/>
![](/images/1-1.png)

這個分層架構分成主要的三塊：Application、Batch Core、及 Batch Infrastructure。Application 包含了整個批次的處理邏輯以及一些客製化的程式碼。Batch Core 包含執行時期用來啟動或控制 Job 所需要的 class，像是 `JobLauncher`、`Job` 和 `Step`。Applicatin 與 Batch Core 都是建立在 Batch Infrastructure 上，Infrastructure 則涵蓋了常見的 readers、writers 和

## Spring Batch 角色
* `job` ( 任務 ) -- 要做什麼事
* `step` ( 步驟 ) -- 完成一個任務所需的步驟

一個 `job` 可以由多個 `step` 來完成，每個 `step` 會對應到一個 `ItemReader`、`ItemProcessor` 及 `ItemWriter`。而 `job` 是透過 `JobLauncher` 來啟動，`job` 與 `step` 執行的結果和狀態都會被儲存在 `JobRepository` 中。

| 物件 | 說明 |
| --- | --- |
Execution Context | 批次處理的執行環境，能夠將所需的餐處在處理任務的過程中進行傳遞
JobRepository | 提供處理任務的持久畫操作，儲存Job、Step執行過程中的狀態及結果
JobLauncher | 執行Job的入口，同時再啟動 Job 的時候可傳遞自定義參數
Job | Spring Batch 的一個批次處理過程，定義了批處理具體的執行邏輯，封裝整個批次處理過程的實例，由一個或多個Step組成
Step | 一個任務的具體的執行邏輯單位
Item | 一條資料記錄
ItemReader | 從資料來源讀取資料，讀取結束後會返回 `null`
ItemProcessor | 對資料進行處理，如資料清洗、轉換、過濾、校驗等，Spring Batch 提供一個 `chunk` 參數，每次任務會寫入一個 `chunk` 的數據，而 `chunk` 的數量取決於任務啟動時候的配置
ItemWriter | 寫入資料到指定目標
Chunk | 給定數量的Item集合，如讀取到chunk數量後，才進行寫操作
Tasklet | Step中具體執行邏輯，可重複執行

## Dependency 
```xml
<!-- MySQL database driver -->
<dependency>
    <groupId>mysql</groupId>
    <artifactId>mysql-connector-java</artifactId>
</dependency>>

<!-- jdbc -->
<dependency>
    <groupId>org.springframework</groupId>
    <artifactId>spring-jdbc</artifactId>
</dependency>

<!-- oxm -->
<dependency>
    <groupId>org.springframework</groupId>
    <artifactId>spring-oxm</artifactId>
</dependency>

<!-- spring batch core -->
<dependency>
    <groupId>org.springframework.batch</groupId>
    <artifactId>spring-batch-core</artifactId>
</dependency>
```

也有人引入下面這兩個 dependency。
```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-startar-batch</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework.batch</groupId>
    <artifactId>spring-batch-test</artifactId>
</dependency>
```

Spring3.0 的一個新特性是` O/XMapper`。O/X 對映器這個概念並不新鮮，O 代表 Object，X 代表 XML。它的目的是在 Java 物件（通常是 POJO）和 XML 文件之間來回轉換。

## Spring Batch 步驟
1. 讀取資料 ( Reader )
2. 處理資料 ( Processor )
3. 寫資料 ( Writer )

## 異常處理機制
* 跳過
* 重試
* 重啟

## 作業方式
* 多執行緒
* 並行
* 遠端
* 分割槽

## 參考
* https://docs.spring.io/spring-batch/docs/4.3.x/reference/html/spring-batch-intro.html#springBatchArchitecture
* https://www.gushiciku.cn/pl/2u5V/zh-tw
* https://blog.csdn.net/qq330983778/article/details/111824575
