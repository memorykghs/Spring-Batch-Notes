# Spring Batch Notes
## 大綱
##### 基礎介紹


* 為何不用 EJB?而用 Spring? 

* 一個 Job 一定會有一個 Step

* tasklet &rArr; 適用於只執行一次； chunk &rArr; 多次執行

* JobLaucher != Quartz，比較像是 Quartz 中的 JobDetail 的角色

* retry 是整個 Step 都可以 retry???

* Conditional Flow

* Job.split() &rArr; 非同步的做法，可以同時帶起所有的 Job

* 多工的時候，Reader 跟 Process 可以綁在一起，但是 Writer 自己是獨立的

* 建議順序
  1. batch + job：是控制批次
  2. step：控制批次流程
  3. chuck：有關資料怎樣處理
  4. chuck 還有特殊優化的 step

* `@EnableJpaRepositories`
* `incrementer()`(Job) 跟 `allowStartComplete()`(Step)：
  step1 -> step2
  step1成功，step2失敗
  若要step1要一起重跑，就要加 allowStartComplete

* 使用 JobOperator 取得 Job 名稱在 Controller 中啟動，會認不得，因為不是 `@Autowired` 出來，並沒有註冊在 Spring IOC 內
  1. JobRegistry
  2. JobLauncher
  3. JobOperator
  4. JobRepository

* JobOperator 是去註冊 Job 的地方找，不是從 Springboot 的 pool 找 (Job 也可以 `@Autowired` 出來執行 )，但 JobOperator 不能塞 JobParamter，只能塞字串
* JobRegistry 對誰註冊??
* 可以自動註冊就不需要用 BatchConfig 手動註冊

---

1. 什麼時候會用到自訂 JobRepository?
2. Writer Process 執行是全部讀完才往下送?
3. PlatformTransactionManager、JpaTransactionManager...?
4. CompositeItemWriterBuilder
5. @OnProcessError、@OnWriteError

---

## ColumnMapRowMapper
使用 `JdbsRepositoryItemReader` 查詢回來直接將查詢結果轉為 Map
* [ColumnMapRowMapper](https://stackoverflow.com/questions/7933336/how-to-use-spring-columnmaprowmapper)

> 範例
```java
```

## Test
- [ ] Spring Batch 例外處理
- [ ] 非同步搭配執行緒
- [ ] 將兩個 Writer 合併成一個

## 其他
* [10 Handy Spring Batch Tricks](https://levelup.gitconnected.com/10-handy-spring-batch-tricks-24556cf549a4)
* [Clear Batch Data Log](https://github.com/arey/spring-batch-toolkit/blob/spring-batch-toolkit-4.0.0/src/main/java/com/javaetmoi/core/batch/tasklet/RemoveSpringBatchHistoryTasklet.java)
* [HikariConfig](https://github.com/brettwooldridge/HikariCP/blob/dev/src/main/java/com/zaxxer/hikari/HikariConfig.java)
