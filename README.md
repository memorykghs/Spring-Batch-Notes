* 為何不用 EJB?而用 Spring? 

* 一個 Job 一定會有一個 Step

* tasklet &rArr; 適用於只執行一次； chunk &rArr; 多次執行

* JobLaucher != Quartz，比較像是 Quartz 中的 JobDetail 的角色

* retry 是整個 Step 都可以 retry???

* Conditional Flow

* Job.split() &rArr; 非同步的做法，可以同時帶起所有的 Job
