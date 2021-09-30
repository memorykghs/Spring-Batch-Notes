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

* D:\Users\.m2\repository\org\springframework\batch\spring-batch-core\4.1.0.RELEASE 以 winrar 開啟

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
2. 