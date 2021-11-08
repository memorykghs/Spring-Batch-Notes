# 01 - Spring Batch 簡介
Spring Batch 是由 Spring Source 和 Accenture ( 埃森哲 ) 合作開發的，可以用來資料抽取、資料庫遷移、資料同步等。Spring Batch 只專注於處理邏輯的抽象，跟排程框架是兩回事。可以結合開源的排程框架有 quartz、cron 等等。下圖是 Spring Batch 的分層架構，有較高的多樣化性與可擴展性：<br/>
![](/images/1-1.png)

* Application - 包含所有 Job 和使用 Spring Batch 框架自行撰寫的程式碼。
* Batch Core - 包含控制和啓動批次作業所需的所有 AP 類別，如 JobLauncher、JobRegistry 等等。
* Batch Infrastructure - 包含應用程式和批次處理核心組件與服務，例如 ItemReader、ItemWriter 等等。
<div style="color: red;">Batch Core 跟 Batch Infrastructure 差別?</div><br/>

這個分層架構分成主要的三塊：Application、Batch Core、及 Batch Infrastructure。Application 包含了整個批次的處理邏輯以及一些客製化的程式碼。Batch Core 包含執行時期用來啟動或控制 Job 所需要的 class，像是 `JobLauncher`、`Job` 和 `Step`。Applicatin 與 Batch Core 都是建立在 Batch Infrastructure 上，Infrastructure 則涵蓋了常見的 readers、writers 和 services ( 例：`RetryTemplate` )，這些東西在 Application 跟 Batch Core 都會用到。

## Spring Batch 基礎角色
* `JobRepository`
* `JobLauncher`
* `job` ( 任務 ) -- 要做什麼事
* `step` ( 步驟 ) -- 完成一個任務所需的步驟
  * `Reader` -- 讀取資料
  * `Processor` -- 處理資料
  * `Writer` -- 寫資料 

一個 `job` 可以由多個 `step` 來完成，每個 `step` 會對應到一個 `ItemReader`、`ItemProcessor` 及 `ItemWriter`。而 `job` 是透過 `JobLauncher` 來啟動，`job` 與 `step` 執行的結果和狀態都會被儲存在 `JobRepository` 中。<br/>
![](/images/1-2.png)

## 批次處理原則
在使用批次框架之前，應先考慮專案的目的以及狀況：

* 通常批次處理架構也會影響 online 架構，反之亦然，在建立架構與環境時應考慮到兩邊的狀況。

* 批次是用來處理讀寫大量資料的框架，應避免在批次處理中使用複雜的邏輯。

* 盡量減少系統資源的使用，尤其是 I/O，並避免不必要的 I/O：
  * 從資料庫讀取資料應避免開啟多次連線讀取
  * 減少不必要的 table 或 index scan
  * 使用查詢條件時減少指定特定 key values

* 執行批次作業時，應確保有足夠的內存空間，避免過程中需要耗時重新分配空間。
* 無論讀取 DB 或是檔案，在可能的情況下對資料進行驗證，確保數據完整性。

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

## 異常處理機制
* 跳過 ( Skip )
* 重試 ( Retry )
* 重啟 ( Restart )

## 作業方式
* 多執行緒
* 並行
* 遠端
* 分割槽

## 參考
* https://docs.spring.io/spring-batch/docs/4.3.x/reference/html/spring-batch-intro.html#springBatchArchitecture
* https://www.gushiciku.cn/pl/2u5V/zh-tw
* https://blog.csdn.net/qq330983778/article/details/111824575
