# 07 - Java Config 配置與註冊 Job

Spring 3 之後可以用 Java 配置來取代 XML 配置，Spring Batch 2.2.0 之後，Job 也可以使用 Java 配置。Spring Batch 的基本 Java 配置是基於兩個 components：
1. `@EnableBatchProcessing` 標註
2. 兩個 Builder：`JobBuilderFactory` 及 `StepBuilderFactory`

`@EnableBatchProcessing` 會提供建立批次作業的基本環境配置，在基本配置中，除了建立 StepScope 實例外，還提供了一些可以自動裝配的 Bean：
* `JobRepository`：bean name "jobRepository"
* `JobLauncher`：bean name "jobLauncher"
* `JobRegistry`：bean name "jobRegistry"
* `PlatformTransactionManager`：bean name "transactionManager"
* `JobBuilderFactory`：bean name "jobBuilders"
* `StepBuilderFactory`：bean name "stepBuilders"

此配置的核心是 `BatchConfigurer`，預設會提供上面提到的 Bean 的實例，以及執行環境中需要的 `DataSource` 的 Bean。這些建立出來的 Bean 以及數據會被 JpaRepository 持久化。也可以透過實作 `BatchConfigurer` 介面來自定需要的 Bean，通常是繼承 `DefaultBatchConfigurer` 並 override 所需的 getter 即可。例：
```java
@Bean
public BatchConfigurer batchConfigurer(DataSource dataSource) {
	return new DefaultBatchConfigurer(dataSource) {
		@Override
		public PlatformTransactionManager getTransactionManager() {
			return new MyTransactionManager();
		}
	};
}
```

## 配置 JobRepository
其實只要在 Application 上使用 `@EnableBatchProcessing` 就會有預設的 JobRepository，當然 Spring Batch 也有提供客製化 JobRepository 的方法。JobRepository 的功能就是用於對 Spring Batch 中各種持久化對象的基本 CRUD 操作，像是 `JobExecution`、`StepExecution` 等物件就會被儲存在 JobRepository 中。

那在預設的情況下，是怎麼自動配置 JobRepository 的呢?
###### Step 1

首先 Spring 相關的自動配置，都會放在 `spring.boot.autoconfigure.jar` 中，在 Maven 管理的 jar 中可以找到。找到之後打開跟 Batch 有關的 packag，裡面有一個 `BatchAutoConfiguration.java` 的類別。<br/>
![](/images/8-5.png)

###### Step 2
`BatchAutoConfiguration.java` 檔案如下，可以發現裡面基本上都是注入已經存在的 `JobRepository` 的 Bean，代表其實不是在這個類別中產生的。
```java
@Configuration(proxyBeanMethods = false)
@ConditionalOnClass({ JobLauncher.class, DataSource.class })
@AutoConfigureAfter(HibernateJpaAutoConfiguration.class)
@ConditionalOnBean(JobLauncher.class)
@EnableConfigurationProperties(BatchProperties.class)
@Import({ BatchConfigurerConfiguration.class, DatabaseInitializationDependencyConfigurer.class })
public class BatchAutoConfiguration {

	@Bean
	@ConditionalOnMissingBean
	@ConditionalOnProperty(prefix = "spring.batch.job", name = "enabled", havingValue = "true", matchIfMissing = true)
	public JobLauncherApplicationRunner jobLauncherApplicationRunner(JobLauncher jobLauncher, JobExplorer jobExplorer,
			JobRepository jobRepository, BatchProperties properties) {
		JobLauncherApplicationRunner runner = new JobLauncherApplicationRunner(jobLauncher, jobExplorer, jobRepository);
		String jobNames = properties.getJob().getNames();
		if (StringUtils.hasText(jobNames)) {
			runner.setJobNames(jobNames);
		}
		return runner;
	}

	@Bean
	@ConditionalOnMissingBean(ExitCodeGenerator.class)
	public JobExecutionExitCodeGenerator jobExecutionExitCodeGenerator() {
		return new JobExecutionExitCodeGenerator();
	}

	@Bean
	@ConditionalOnMissingBean(JobOperator.class)
	public SimpleJobOperator jobOperator(ObjectProvider<JobParametersConverter> jobParametersConverter,
			JobExplorer jobExplorer, JobLauncher jobLauncher, ListableJobLocator jobRegistry,
			JobRepository jobRepository) throws Exception {
		SimpleJobOperator factory = new SimpleJobOperator();
		factory.setJobExplorer(jobExplorer);
		factory.setJobLauncher(jobLauncher);
		factory.setJobRegistry(jobRegistry);
		factory.setJobRepository(jobRepository);
		jobParametersConverter.ifAvailable(factory::setJobParametersConverter);
		return factory;
	}

	@Configuration(proxyBeanMethods = false)
	@ConditionalOnBean(DataSource.class)
	@ConditionalOnClass(DatabasePopulator.class)
	static class DataSourceInitializerConfiguration {

		@Bean
		@ConditionalOnMissingBean
		BatchDataSourceInitializer batchDataSourceInitializer(DataSource dataSource,
				@BatchDataSource ObjectProvider<DataSource> batchDataSource, ResourceLoader resourceLoader,
				BatchProperties properties) {
			return new BatchDataSourceInitializer(batchDataSource.getIfAvailable(() -> dataSource), resourceLoader,
					properties);
		}
	}
}
```
看起來最相關的是上方 `@Import` Annotation 中帶的  `BatchConfigurerConfiguration` 這個類別，再點進去看。

###### Step 3
`BatchConfigurerConfiguration.java` 檔案內容如下，看起來也沒有發現注入 `JobRepository`，比較相關的類別則是 `JdbcBatchConfiguration` 類中的 `batchConfigurer()` 方法，裡面建立了 `BasicBatchConfigurer` 實例。
```java
@ConditionalOnClass(PlatformTransactionManager.class)
@ConditionalOnBean(DataSource.class)
@ConditionalOnMissingBean(BatchConfigurer.class)
@Configuration(proxyBeanMethods = false)
class BatchConfigurerConfiguration {

	@Configuration(proxyBeanMethods = false)
	@ConditionalOnMissingBean(name = "entityManagerFactory")
	static class JdbcBatchConfiguration {

		@Bean
		BasicBatchConfigurer batchConfigurer(BatchProperties properties, DataSource dataSource,
				@BatchDataSource ObjectProvider<DataSource> batchDataSource,
				ObjectProvider<TransactionManagerCustomizers> transactionManagerCustomizers) {
			return new BasicBatchConfigurer(properties, batchDataSource.getIfAvailable(() -> dataSource),
					transactionManagerCustomizers.getIfAvailable());
		}

	}

	@Configuration(proxyBeanMethods = false)
	@ConditionalOnClass(EntityManagerFactory.class)
	@ConditionalOnBean(name = "entityManagerFactory")
	static class JpaBatchConfiguration {

		@Bean
		JpaBatchConfigurer batchConfigurer(BatchProperties properties, DataSource dataSource,
				@BatchDataSource ObjectProvider<DataSource> batchDataSource,
				ObjectProvider<TransactionManagerCustomizers> transactionManagerCustomizers,
				EntityManagerFactory entityManagerFactory) {
			return new JpaBatchConfigurer(properties, batchDataSource.getIfAvailable(() -> dataSource),
					transactionManagerCustomizers.getIfAvailable(), entityManagerFactory);
		}

	}
}
```

###### Step 4
進入 `BasicBatchConfigurer.java` 後，會發現裡面有一個 `initialize()` 方法，使用 `createXXX()` 建立了一些初始化所需的物件。
```java
public void initialize() {
	try {
		this.transactionManager = buildTransactionManager();
		this.jobRepository = createJobRepository();
		this.jobLauncher = createJobLauncher();
		this.jobExplorer = createJobExplorer();
	}
	catch (Exception ex) {
		throw new IllegalStateException("Unable to initialize Spring Batch", ex);
	}
}
```

像是 `createJobRepository()` 方法內容如下：
```java
protected JobRepository createJobRepository() throws Exception {
	JobRepositoryFactoryBean factory = new JobRepositoryFactoryBean();
	PropertyMapper map = PropertyMapper.get();
	map.from(this.dataSource).to(factory::setDataSource);
	map.from(this::determineIsolationLevel).whenNonNull().to(factory::setIsolationLevelForCreate);
	map.from(this.properties.getJdbc()::getTablePrefix).whenHasText().to(factory::setTablePrefix);
	map.from(this::getTransactionManager).to(factory::setTransactionManager);
	factory.afterPropertiesSet();
	return factory.getObject();
}
```
裡面定義了一些自訂 `JobRepository` 需要自訂的屬性。

###### Step 5
回頭來看 Step 3 中的 `BatchConfigurerConfiguration.java`，上面有一個註解 `@ConditionalOnMissingBean(BatchConfigurer.class)`，當找不到 `BatchConfigurer.class` 的實例就會幫當前這個類別建立實例。
```java
@ConditionalOnClass(PlatformTransactionManager.class)
@ConditionalOnBean(DataSource.class)
@ConditionalOnMissingBean(BatchConfigurer.class)
@Configuration(proxyBeanMethods = false)
class BatchConfigurerConfiguration {
```

那 `BatchConfigurer` 實現類別裡面做了什麼呢?打開其實體類別 `DefaultBatchConfigurer.java`。<br/>
![](/images/8-6.png)

會發現其實 `DefaultBatchConfigurer.java` 本身就是一個 Component，並寫有注入一些必要的物件，例如 `DataSource`。<br/>
![](/images/8-7.png)

而且他的 `initialize()` 方法上有 [@PostConstruct](https://www.tpisoftware.com/tpu/articleDetails/442) 標註，代表滿足依賴條件後就會自動初始化這個類別。Spring 框架只要有 DataSource 相關的參數就會自動初始化一個 `EntityManagerFactory`，一旦沒有 `DataSource` 就會報錯。<br/>
![](/images/8-8.png)

## 配置 JobLauncher
當使用 `@EnableBatchProcessing` 標註時，同時也提供了一個默認的 `JobRegistry` 環境。
最常看到時做 `JobLauncher` 介面的物件是 `SimpleJobLauncher`，並且只需要 `JobRepository` 的依賴，例：
```java
...
// This would reside in your BatchConfigurer implementation
@Override
protected JobLauncher createJobLauncher() throws Exception {
	SimpleJobLauncher jobLauncher = new SimpleJobLauncher();
	jobLauncher.setJobRepository(jobRepository);
	jobLauncher.afterPropertiesSet();
	return jobLauncher;
}
...
```

![](/images/8-1.png)

## JobRegistry
在啟動批次的部分，`JobRegistry` ( 其父介面是 `JobLocator` ) 並非一定要配置，不過當想要在執行環境中追蹤哪接 Job 是可以用的，就可以使用他。而使用的最主要目的就是，在 Job 被創建的當下，透過 Job 設定的名稱映射，將這些 Job 收集起來；也可以對這接已經收集到的 Job 做一些屬性或是名稱上的設定。

有兩種自動填充 `JobRegistry`，分別是 `JobRegistryBeanPostProcessor` 和 `AutomaticJobRegistrar`，這邊指針對 `JobRegistryBeanPostProcessor` 介紹。

#### JobRegistryBeanPostProcessor
`JobRegistryBeanPostProcessor` 是透過 `setJobRegistry()` 注入 `JobRegistry` 的，`afterPropertiesSet()` 則是用來確認在使用 `JobRegistry` 之前，是否所有必要的依賴與屬性都被建立好了。
```java
@Bean
public JobRegistryBeanPostProcessor jobRegistryBeanPostProcessor(JobRegistry jobRegistry) throws Exception {
	JobRegistryBeanPostProcessor beanProcessor = new JobRegistryBeanPostProcessor();
	beanProcessor.setJobRegistry(jobRegistry);
	beanProcessor.afterPropertiesSet();
	return beanProcessor;
}
```

`JobRegistry` 本身會注入 `JobFactory`，當我們指定要啟動哪一個 Job 時，`JobRegistry` 會依照給定的 Job Name 去找相對應的 Job，並建立出實例。實作 `JobRegistry` 的類別是 `MapJobRegistry`，下面可以看到當要拿出對應 Job 的時候，會先依照名稱取得相對應的 Job，再呼叫 `JobFactory` 的 `createJob()` 方法。
```java
public class MapJobRegistry implements JobRegistry {
	...
	@Override
	public Job getJob(@Nullable String name) throws NoSuchJobException {
		JobFactory factory = map.get(name);
		if (factory == null) {
			throw new NoSuchJobException("No job configuration with the name [" + name + "] was registered");
		} else {
			return factory.createJob();
		}
	}
	...
}
```

而 `JobFactory` 是從哪裡拿到這些 Job 對向的呢?我們來看看 `JobFactory` 的實作類別 `ApplicationContextJobFactory`。<br/>
![](/images/8-2.png)

以下是 `ApplicationContextJobFactory` 的建構式，可以發現在初始畫時就取得整個 Application 的 context。
```java 
public ApplicationContextJobFactory(String jobName, ApplicationContextFactory applicationContextFactory) {
	@SuppressWarnings("resource")
	ConfigurableApplicationContext context = applicationContextFactory.createApplicationContext();
	this.job = context.getBean(jobName, Job.class);
}
```
<br/>

![](/images/8-3.png)

所以其實也就是從整個應用程式的 context 中拿出所需要的 Job。

## 小結
![](/images/8-4.png)

## 設定 BatchConfig
```
spring.batch.springBatchPractice.config // 新增
  |--BatchConfig.java // 新增
```

`BatchConfig.java`
```java
@Configuration
public class BatchConfig extends DefaultBatchConfigurer {

	/**
	 * 產生 Step Transaction
	 * @return
	 */
	@Bean
	public JpaTransactionManager jpaTransactionManager(DataSource dataSource) {
		final JpaTransactionManager transactionManager = new JpaTransactionManager();
		transactionManager.setDataSource(dataSource);
		return transactionManager;
	}

	/**
	 * 使用 JobRegistry 註冊 Job
	 * @param jobRegistry
	 * @return
	 * @throws Exception
	 */
	@Bean
	public JobRegistryBeanPostProcessor jobRegistryBeanPostProcessor(JobRegistry jobRegistry) throws Exception {
		JobRegistryBeanPostProcessor beanProcessor = new JobRegistryBeanPostProcessor();
		beanProcessor.setJobRegistry(jobRegistry);
			beanProcessor.afterPropertiesSet();
		return beanProcessor;
	}
}
```
首先會先在 `BatchConfig.java` 這個類別上加上 `@EnableBatchProcessing` 註解，讓我們可以運行 Spring Batch。加上註解後，Spring 會自動幫我們產生與 Spring Batch 相關的 Bean，並將這些 Bean 交給 Spring 容器管理。

## 參考
* https://blog.csdn.net/Chris___/article/details/103352103
* https://docs.spring.io/spring-batch/docs/4.3.x/reference/html/job.html#javaConfig
* https://www.gushiciku.cn/pl/gDAV/zh-tw
* https://www.twblogs.net/a/5dbbbab3bd9eee310da08dce/?lang=zh-cn
