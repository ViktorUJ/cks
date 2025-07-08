# AWS AI Practitioner  example questions

Click **Answer** to reveal the correct option with an explanation.

### 1. Which AWS service provides pre-built ML algorithms and frameworks?

**Options:**

- **A.** Amazon SageMaker Built-in Algorithms
- **B.** AWS Lambda
- **C.** Amazon EC2
- **D.** Amazon ECS

<details><summary>Answer</summary>

**Correct answer:** A. Amazon SageMaker Built-in Algorithms  

*Explanation:* SageMaker ships with a library of built‑in algorithms that you can train on your own data without writing algorithm code — letting you start faster.  
Documentation: <https://docs.aws.amazon.com/sagemaker/latest/dg/algos.html>

</details>

### 2. Which AWS service provides pre-built AI services that can be easily integrated into applications?

**Options:**

- **A.** Amazon SageMaker
- **B.** AWS AI Services
- **C.** Amazon EC2
- **D.** AWS Lambda

<details><summary>Answer</summary>

**Correct answer:** B. AWS AI Services  

*Explanation:* AWS offers a family of AI Services (Rekognition, Comprehend, Translate, etc.) that are pre‑trained and exposed behind simple APIs for easy integration, so you don’t need ML expertise.  
Documentation: <https://aws.amazon.com/machine-learning/ai-services/>

</details>

### 3. What is the bias-variance tradeoff?

**Options:**

- **A.** The balance between model complexity and generalization ability
- **B.** The choice between different algorithms
- **C.** The tradeoff between training time and accuracy
- **D.** The balance between different types of data

<details><summary>Answer</summary>

**Correct answer:** A. The balance between model complexity and generalization ability  

*Explanation:* The trade‑off explains how increasing model complexity can lower bias but raise variance, and vice‑versa; a good model finds the sweet spot between the two.  
Documentation: <https://docs.aws.amazon.com/machine-learning/latest/dg/bias-variance.html>

</details>

### 4. What is Amazon Transcribe Medical designed for?

**Options:**

- **A.** General speech recognition
- **B.** Medical speech recognition with healthcare-specific vocabulary
- **C.** Medical image analysis
- **D.** Medical data storage

<details><summary>Answer</summary>

**Correct answer:** B. Medical speech recognition with healthcare-specific vocabulary  

*Explanation:* Transcribe Medical is a variant of Amazon Transcribe tuned for clinical dictation and tele‑health conversations, recognising medical terminology securely.  
Documentation: <https://docs.aws.amazon.com/transcribe/latest/dg/medical-transcription.html>

</details>

### 5. Which AWS service can perform real-time language detection?

**Options:**

- **A.** Amazon Translate
- **B.** Amazon Comprehend
- **C.** Amazon Polly
- **D.** Amazon Lex

<details><summary>Answer</summary>

**Correct answer:** B. Amazon Comprehend  

*Explanation:* Amazon Comprehend’s `DetectDominantLanguage` API identifies the primary language of text in real time.  
Documentation: <https://docs.aws.amazon.com/comprehend/latest/dg/how-languages.html>

</details>

### 6. Which SageMaker feature provides managed Jupyter notebooks?

**Options:**

- **A.** SageMaker Studio
- **B.** SageMaker Endpoints
- **C.** SageMaker Pipelines
- **D.** SageMaker Feature Store

<details><summary>Answer</summary>

**Correct answer:** A. SageMaker Studio  

*Explanation:* SageMaker Studio gives you fully managed Jupyter‑compatible notebooks inside an integrated ML IDE that runs in the browser.  
Documentation: <https://docs.aws.amazon.com/sagemaker/latest/dg/studio.html>

</details>

### 7. What is Amazon Bedrock?

**Options:**

- **A.** A database service
- **B.** A fully managed service for foundation models
- **C.** A container orchestration service
- **D.** A networking service

<details><summary>Answer</summary>

**Correct answer:** B. A fully managed service for foundation models  

*Explanation:* Amazon Bedrock lets you discover, customize and deploy foundation models from AWS and leading model providers via API.  
Documentation: <https://docs.aws.amazon.com/bedrock/latest/userguide/what-is-bedrock.html>

</details>

### 8. Which AWS service can be used for distributed training of large ML models?

**Options:**

- **A.** Amazon SageMaker Distributed Training
- **B.** AWS Lambda
- **C.** Amazon ECS
- **D.** Amazon EC2

<details><summary>Answer</summary>

**Correct answer:** A. Amazon SageMaker Distributed Training  

*Explanation:* SageMaker’s distributed training libraries split large deep‑learning models or datasets across GPUs/instances to shorten training time.  
Documentation: <https://docs.aws.amazon.com/sagemaker/latest/dg/distributed-training.html>

</details>

### 9. Which SageMaker feature provides automatic model tuning?

**Options:**

- **A.** SageMaker Automatic Model Tuning
- **B.** SageMaker Autopilot
- **C.** SageMaker Clarify
- **D.** SageMaker Debugger

<details><summary>Answer</summary>

**Correct answer:** A. SageMaker Automatic Model Tuning  

*Explanation:* Also called Hyperparameter Tuning Jobs, it automatically searches hyperparameter space to find the best model configuration.  
Documentation: <https://docs.aws.amazon.com/sagemaker/latest/dg/automatic-model-tuning.html>

</details>

### 10. What is SageMaker Pipelines used for?

**Options:**

- **A.** Creating ML workflows and automating ML operations
- **B.** Storing data
- **C.** Monitoring models
- **D.** Scaling endpoints

<details><summary>Answer</summary>

**Correct answer:** A. Creating ML workflows and automating ML operations  

*Explanation:* Pipelines is a CI/CD service for ML that defines and executes repeatable, versioned ML workflows.  
Documentation: <https://docs.aws.amazon.com/sagemaker/latest/dg/pipelines.html>

</details>

### 11. What is the purpose of a training dataset in machine learning?

**Options:**

- **A.** To test the final model's performance
- **B.** To teach the model to recognize patterns
- **C.** To store the model's predictions
- **D.** To validate hyperparameters

<details><summary>Answer</summary>

**Correct answer:** B. To teach the model to recognize patterns  

*Explanation:* The training set supplies labeled examples from which the algorithm learns the mapping between features and target.  
Documentation: <https://docs.aws.amazon.com/machine-learning/latest/dg/understanding-data.html>

</details>

### 12. Which SageMaker component is used for hosting trained models?

**Options:**

- **A.** SageMaker Training Jobs
- **B.** SageMaker Endpoints
- **C.** SageMaker Notebooks
- **D.** SageMaker Processing Jobs

<details><summary>Answer</summary>

**Correct answer:** B. SageMaker Endpoints  

*Explanation:* Real‑time inference is served from HTTPS endpoints that SageMaker scales and manages for you.  
Documentation: <https://docs.aws.amazon.com/sagemaker/latest/dg/deploy-endpoint.html>

</details>

### 13. What is SageMaker Model Monitor used for?

**Options:**

- **A.** Training models
- **B.** Monitoring deployed models for data drift and model degradation
- **C.** Creating datasets
- **D.** Optimizing model performance

<details><summary>Answer</summary>

**Correct answer:** B. Monitoring deployed models for data drift and model degradation  

*Explanation:* Model Monitor automatically captures inference data and alerts when data quality or prediction quality drifts.  
Documentation: <https://docs.aws.amazon.com/sagemaker/latest/dg/model-monitor.html>

</details>

### 14. Which AWS service would you use to detect personally identifiable information (PII) in text?

**Options:**

- **A.** Amazon Macie
- **B.** Amazon Comprehend
- **C.** Amazon GuardDuty
- **D.** Amazon Inspector

<details><summary>Answer</summary>

**Correct answer:** B. Amazon Comprehend  

*Explanation:* Comprehend’s PII API detects and redacts sensitive data such as names, SSNs, phone numbers, etc.  
Documentation: <https://docs.aws.amazon.com/comprehend/latest/dg/pii.html>

</details>

### 15. Which AWS service can automatically scale ML model endpoints based on traffic?

**Options:**

- **A.** Amazon EC2 Auto Scaling
- **B.** SageMaker Automatic Scaling
- **C.** AWS Lambda
- **D.** Amazon ECS

<details><summary>Answer</summary>

**Correct answer:** B. SageMaker Automatic Scaling  

*Explanation:* Using Application Auto Scaling, SageMaker can increase or decrease the number of instances behind an endpoint according to load.  
Documentation: <https://docs.aws.amazon.com/sagemaker/latest/dg/endpoint-auto-scaling.html>

</details>

### 16. What is Amazon Textract primarily designed for?

**Options:**

- **A.** Generating text from images
- **B.** Extracting text and data from documents
- **C.** Translating text
- **D.** Analyzing text sentiment

<details><summary>Answer</summary>

**Correct answer:** B. Extracting text and data from documents  

*Explanation:* Textract uses OCR and ML to detect text, forms and tables from scanned docs — turning documents into structured data.  
Documentation: <https://docs.aws.amazon.com/textract/latest/dg/what-is.html>

</details>

### 17. What is model versioning important for in ML operations?

**Options:**

- **A.** Reducing storage costs
- **B.** Tracking model changes and enabling rollbacks
- **C.** Improving model accuracy
- **D.** Speeding up inference

<details><summary>Answer</summary>

**Correct answer:** B. Tracking model changes and enabling rollbacks  

*Explanation:* Versioning lets teams trace, compare and safely roll back model iterations, a key MLOps best practice.  
Documentation: <https://docs.aws.amazon.com/sagemaker/latest/dg/model-version.html>

</details>

### 18. What is A/B testing in the context of ML model deployment?

**Options:**

- **A.** Testing two different datasets
- **B.** Comparing the performance of different model versions
- **C.** Testing model security
- **D.** Testing model storage options

<details><summary>Answer</summary>

**Correct answer:** B. Comparing the performance of different model versions  

*Explanation:* Traffic is split between two (or more) model variants to measure live performance and pick the best one.  
Documentation: <https://docs.aws.amazon.com/sagemaker/latest/dg/model-abtesting.html>

</details>

### 19. Which AWS service would you use to build conversational chatbots?

**Options:**

- **A.** Amazon Comprehend
- **B.** Amazon Lex
- **C.** Amazon Polly
- **D.** Amazon Rekognition

<details><summary>Answer</summary>

**Correct answer:** B. Amazon Lex  

*Explanation:* Lex provides speech recognition + NLU so you can design, test and deploy chatbots directly to web or voice channels.  
Documentation: <https://docs.aws.amazon.com/lexv2/latest/dg/what-is.html>

</details>

### 20. What is the purpose of regularization in machine learning?

**Options:**

- **A.** To increase model complexity
- **B.** To prevent overfitting by adding penalties to the loss function
- **C.** To speed up training
- **D.** To increase the size of the dataset

<details><summary>Answer</summary>

**Correct answer:** B. To prevent overfitting by adding penalties to the loss function  

*Explanation:* Techniques like L1/L2 add a cost for large weights so the model generalizes better.  
Documentation: <https://docs.aws.amazon.com/machine-learning/latest/dg/regularization.html>

</details>

### 21. What is the difference between AI, ML, and Deep Learning?

**Options:**

- **A.** They are all the same thing
- **B.** AI is the broadest term, ML is a subset of AI, Deep Learning is a subset of ML
- **C.** ML is the broadest term, AI is a subset of ML
- **D.** Deep Learning came before ML and AI

<details><summary>Answer</summary>

**Correct answer:** B. AI is the broadest term, ML is a subset of AI, Deep Learning is a subset of ML  

*Explanation:* AI ⊃ ML ⊃ DL — deep learning uses multi‑layer neural networks, ML uses algorithms trained on data, AI is any system that appears intelligent.  
Documentation: <https://docs.aws.amazon.com/machine-learning/latest/dg/overview.html>

</details>

### 22. Which technique is used to deploy models gradually to reduce risk?

**Options:**

- **A.** Blue-green deployment
- **B.** Canary deployment
- **C.** Rolling deployment
- **D.** All of the above

<details><summary>Answer</summary>

**Correct answer:** B. Canary deployment  

*Explanation:* A small percentage of traffic is sent to the new model first; if metrics look good, traffic is increased.  
Documentation: <https://docs.aws.amazon.com/sagemaker/latest/dg/cicd.html#cicd-canary>

</details>

### 23. Which AWS service provides pre-trained computer vision models via API?

**Options:**

- **A.** Amazon SageMaker
- **B.** Amazon Rekognition
- **C.** Amazon EC2
- **D.** Amazon S3

<details><summary>Answer</summary>

**Correct answer:** B. Amazon Rekognition  

*Explanation:* Rekognition exposes pre‑trained image & video analysis (object, face, moderation, etc.) through API calls.  
Documentation: <https://docs.aws.amazon.com/rekognition/latest/dg/what-is.html>

</details>

### 24. Which of the following best describes artificial neural networks?

**Options:**

- **A.** Networks of interconnected nodes that mimic the human brain
- **B.** Physical networks of computers
- **C.** Database connection networks
- **D.** Internet networking protocols

<details><summary>Answer</summary>

**Correct answer:** A. Networks of interconnected nodes that mimic the human brain  

*Explanation:* ANNs are layers of artificial “neurons” whose weighted connections enable complex non‑linear learning.  
Documentation: <https://docs.aws.amazon.com/machine-learning/latest/dg/ann.html>

</details>

### 25. Which AWS service would you use for medical text analysis?

**Options:**

- **A.** Amazon Comprehend
- **B.** Amazon Comprehend Medical
- **C.** Amazon Textract
- **D.** Amazon Translate

<details><summary>Answer</summary>

**Correct answer:** B. Amazon Comprehend Medical  

*Explanation:* Comprehend Medical extracts PHI and medical entities (conditions, medications, tests, etc.) from clinical text.  
Documentation: <https://docs.aws.amazon.com/comprehend/latest/dg/what-is-comprehend-med.html>

</details>

### 26. What is Amazon Rekognition Custom Labels used for?

**Options:**

- **A.** Creating custom image classification models
- **B.** Generating image labels automatically
- **C.** Storing image metadata
- **D.** Compressing images

<details><summary>Answer</summary>

**Correct answer:** A. Creating custom image classification models  

*Explanation:* It lets you train a model on your own labeled images without writing CV code — ideal for domain‑specific objects.  
Documentation: <https://docs.aws.amazon.com/rekognition/latest/customlabels-dg/what-is.html>

</details>

### 27. What is Amazon Comprehend designed to do?

**Options:**

- **A.** Generate images from text
- **B.** Extract insights from text using natural language processing
- **C.** Convert speech to text
- **D.** Translate languages

<details><summary>Answer</summary>

**Correct answer:** B. Extract insights from text using natural language processing  

*Explanation:* Comprehend performs NLP tasks such as sentiment, entities, key phrases, topics and language detection.  
Documentation: <https://docs.aws.amazon.com/comprehend/latest/dg/what-is.html>

</details>

### 28. Which AWS service would you use for automatic speech recognition?

**Options:**

- **A.** Amazon Polly
- **B.** Amazon Transcribe
- **C.** Amazon Translate
- **D.** Amazon Comprehend

<details><summary>Answer</summary>

**Correct answer:** B. Amazon Transcribe  

*Explanation:* Transcribe converts spoken language to text and supports batch and real‑time streaming.  
Documentation: <https://docs.aws.amazon.com/transcribe/latest/dg/what-is.html>

</details>

### 29. What is the purpose of SageMaker Feature Store?

**Options:**

- **A.** To store trained models
- **B.** To store and manage ML features for training and inference
- **C.** To store datasets
- **D.** To store model artifacts

<details><summary>Answer</summary>

**Correct answer:** B. To store and manage ML features for training and inference  

*Explanation:* The feature store provides central, versioned, online & offline feature access to ensure consistency.  
Documentation: <https://docs.aws.amazon.com/sagemaker/latest/dg/feature-store.html>

</details>

### 30. Which AWS service would you use for time series forecasting?

**Options:**

- **A.** Amazon Personalize
- **B.** Amazon Forecast
- **C.** Amazon Comprehend
- **D.** Amazon Rekognition

<details><summary>Answer</summary>

**Correct answer:** B. Amazon Forecast  

*Explanation:* Forecast is a fully managed service that uses AWS research (based on DeepAR+) to predict future demand or metrics.  
Documentation: <https://docs.aws.amazon.com/forecast/latest/dg/what-is-forecast.html>

</details>

### 31. Which of the following is an example of unsupervised learning?

**Options:**

- **A.** Email spam detection
- **B.** Customer segmentation through clustering
- **C.** Predicting stock prices
- **D.** Image classification

<details><summary>Answer</summary>

**Correct answer:** B. Customer segmentation through clustering  

*Explanation:* Clustering groups customers without labels to discover natural segments.  
Documentation: <https://docs.aws.amazon.com/machine-learning/latest/dg/unsupervised.html>

</details>

### 32. Which AWS service would you use to extract insights from contact center conversations?

**Options:**

- **A.** Amazon Connect
- **B.** Amazon Transcribe Call Analytics
- **C.** Amazon Comprehend
- **D.** Amazon Lex

<details><summary>Answer</summary>

**Correct answer:** B. Amazon Transcribe Call Analytics  

*Explanation:* Call Analytics runs ASR + sentiment + call driver analysis on recorded or real‑time calls.  
Documentation: <https://docs.aws.amazon.com/transcribe/latest/dg/call-analytics.html>

</details>

### 33. What is the purpose of SageMaker Clarify?

**Options:**

- **A.** To improve model accuracy
- **B.** To detect bias in ML models and explain model predictions
- **C.** To reduce training time
- **D.** To compress models

<details><summary>Answer</summary>

**Correct answer:** B. To detect bias in ML models and explain model predictions  

*Explanation:* Clarify generates bias metrics & SHAP explanations during training and after deployment.  
Documentation: <https://docs.aws.amazon.com/sagemaker/latest/dg/clarify.html>

</details>

### 34. Which of the following is an example of a regression problem?

**Options:**

- **A.** Predicting whether an email is spam or not spam
- **B.** Predicting the price of a house based on its features
- **C.** Clustering customers into different segments
- **D.** Classifying images of cats and dogs

<details><summary>Answer</summary>

**Correct answer:** B. Predicting the price of a house based on its features  

*Explanation:* Regression predicts continuous numeric values, e.g., price, temperature.  
Documentation: <https://docs.aws.amazon.com/machine-learning/latest/dg/regression.html>

</details>

### 35. Which of the following is a key principle of responsible AI?

**Options:**

- **A.** Maximizing profit
- **B.** Ensuring fairness and avoiding bias
- **C.** Using the most complex models available
- **D.** Collecting as much data as possible

<details><summary>Answer</summary>

**Correct answer:** B. Ensuring fairness and avoiding bias  

*Explanation:* AWS Responsible AI pillars include fairness, explainability, privacy and robustness.  
Documentation: <https://aws.amazon.com/responsible-ai/>

</details>

### 36. Which AWS service would you use to build question-answering systems?

**Options:**

- **A.** Amazon Kendra
- **B.** Amazon Lex
- **C.** Amazon Comprehend
- **D.** Amazon Translate

<details><summary>Answer</summary>

**Correct answer:** A. Amazon Kendra  

*Explanation:* Kendra is an intelligent search service that returns exact answers, not just documents.  
Documentation: <https://docs.aws.amazon.com/kendra/latest/dg/what-is-kendra.html>

</details>

### 37. What is overfitting in machine learning?

**Options:**

- **A.** When a model performs well on training data but poorly on new data
- **B.** When a model takes too long to train
- **C.** When a model uses too much memory
- **D.** When a model has too few parameters

<details><summary>Answer</summary>

**Correct answer:** A. When a model performs well on training data but poorly on new data  

*Explanation:* Overfitting means the model has memorised noise and lost generalisation.  
Documentation: <https://docs.aws.amazon.com/machine-learning/latest/dg/overfitting.html>

</details>

### 38. Which AWS service provides personalized recommendations?

**Options:**

- **A.** Amazon Personalize
- **B.** Amazon Forecast
- **C.** Amazon Textract
- **D.** Amazon Comprehend

<details><summary>Answer</summary>

**Correct answer:** A. Amazon Personalize  

*Explanation:* Personalize brings the same technology behind Amazon.com recommendations as a fully managed service.  
Documentation: <https://docs.aws.amazon.com/personalize/latest/dg/what-is-personalize.html>

</details>

### 39. What is the purpose of data preprocessing in machine learning?

**Options:**

- **A.** To make data ready for model training
- **B.** To increase the size of the dataset
- **C.** To reduce storage costs
- **D.** To make data more complex

<details><summary>Answer</summary>

**Correct answer:** A. To make data ready for model training  

*Explanation:* Cleaning, normalising and encoding data improve model quality and convergence.  
Documentation: <https://docs.aws.amazon.com/machine-learning/latest/dg/preprocessing.html>

</details>

### 40. What is Amazon CodeWhisperer designed to do?

**Options:**

- **A.** Generate code comments
- **B.** Provide AI-powered code suggestions
- **C.** Debug code automatically
- **D.** Translate code between languages

<details><summary>Answer</summary>

**Correct answer:** B. Provide AI-powered code suggestions  

*Explanation:* CodeWhisperer generates real‑time code completions & snippets based on natural language or existing code context.  
Documentation: <https://docs.aws.amazon.com/codewhisperer/latest/userguide/what-is.html>

</details>

### 41. Which AWS service can be used for batch inference with ML models?

**Options:**

- **A.** Amazon SageMaker Batch Transform
- **B.** AWS Lambda
- **C.** Amazon ECS
- **D.** Amazon EC2

<details><summary>Answer</summary>

**Correct answer:** A. Amazon SageMaker Batch Transform  

*Explanation:* Batch Transform runs offline inference on large datasets without deploying persistent endpoints.  
Documentation: <https://docs.aws.amazon.com/sagemaker/latest/dg/batch-transform.html>

</details>

### 42. What is the primary purpose of Amazon A2I (Augmented AI)?

**Options:**

- **A.** To replace human workers entirely
- **B.** To add human review to ML predictions when needed
- **C.** To automate all AI processes
- **D.** To generate artificial data

<details><summary>Answer</summary>

**Correct answer:** B. To add human review to ML predictions when needed  

*Explanation:* A2I routes low‑confidence predictions to human reviewers using configurable workflows.  
Documentation: <https://docs.aws.amazon.com/sagemaker/latest/dg/a2i.html>

</details>

### 43. Which SageMaker feature helps reduce model training costs?

**Options:**

- **A.** SageMaker Spot Training
- **B.** SageMaker Endpoints
- **C.** SageMaker Studio
- **D.** SageMaker Ground Truth

<details><summary>Answer</summary>

**Correct answer:** A. SageMaker Spot Training  

*Explanation:* Spot Training uses spare EC2 capacity at up to 90% discount, automatically checkpointing to resume if interrupted.  
Documentation: <https://docs.aws.amazon.com/sagemaker/latest/dg/model-training-modes.html#spot_instances>

</details>

### 44. Which type of learning is used when an AI system learns through trial and error with rewards and penalties?

**Options:**

- **A.** Supervised learning
- **B.** Unsupervised learning
- **C.** Reinforcement learning
- **D.** Transfer learning

<details><summary>Answer</summary>

**Correct answer:** C. Reinforcement learning  

*Explanation:* The agent explores an environment, receiving reward signals that shape its policy.  
Documentation: <https://docs.aws.amazon.com/robomaker/latest/dg/what-is-rl.html>

</details>

### 45. What is Amazon Lookout for Vision used for?

**Options:**

- **A.** Detecting defects in manufacturing using computer vision
- **B.** Creating virtual reality experiences
- **C.** Generating images
- **D.** Translating visual content

<details><summary>Answer</summary>

**Correct answer:** A. Detecting defects in manufacturing using computer vision  

*Explanation:* Lookout for Vision trains a custom CV model to spot anomalies on production lines.  
Documentation: <https://docs.aws.amazon.com/lookout-for-vision/latest/developer-guide/what-is.html>

</details>

### 46. What is the difference between real-time and batch inference?

**Options:**

- **A.** Real-time processes single requests immediately, batch processes multiple requests together
- **B.** Real-time is more accurate than batch
- **C.** Batch is faster than real-time
- **D.** There is no difference

<details><summary>Answer</summary>

**Correct answer:** A. Real-time processes single requests immediately, batch processes multiple requests together  

*Explanation:* Real‑time endpoints deliver low‑latency predictions; batch jobs run asynchronously on large datasets.  
Documentation: <https://docs.aws.amazon.com/sagemaker/latest/dg/realtime-batch.html>

</details>

### 47. What is Amazon Polly's Neural Text-to-Speech (NTTS) feature?

**Options:**

- **A.** Faster text processing
- **B.** More natural-sounding speech synthesis
- **C.** Better text recognition
- **D.** Improved translation accuracy

<details><summary>Answer</summary>

**Correct answer:** B. More natural-sounding speech synthesis  

*Explanation:* NTTS uses a new neural engine that produces more human‑like prosody and intonation.  
Documentation: <https://docs.aws.amazon.com/polly/latest/dg/ntts.html>

</details>

### 48. What is the purpose of SageMaker Ground Truth?

**Options:**

- **A.** To deploy models
- **B.** To create high-quality training datasets through data labeling
- **C.** To monitor model performance
- **D.** To store model artifacts

<details><summary>Answer</summary>

**Correct answer:** B. To create high-quality training datasets through data labeling  

*Explanation:* Ground Truth manages workforces, labeling workflows & active learning to build annotated datasets.  
Documentation: <https://docs.aws.amazon.com/sagemaker/latest/dg/sms.html>

</details>

### 49. Which AWS service can convert text to speech?

**Options:**

- **A.** Amazon Transcribe
- **B.** Amazon Polly
- **C.** Amazon Translate
- **D.** Amazon Lex

<details><summary>Answer</summary>

**Correct answer:** B. Amazon Polly  

*Explanation:* Polly turns text into lifelike speech in dozens of languages and voices.  
Documentation: <https://docs.aws.amazon.com/polly/latest/dg/what-is.html>

</details>

### 50. What is the purpose of a validation dataset?

**Options:**

- **A.** To train the model
- **B.** To tune hyperparameters and prevent overfitting
- **C.** To store the final predictions
- **D.** To increase the training data size

<details><summary>Answer</summary>

**Correct answer:** B. To tune hyperparameters and prevent overfitting  

*Explanation:* The validation set guides model selection and early stopping without biasing the final test evaluation.  
Documentation: <https://docs.aws.amazon.com/machine-learning/latest/dg/validation-dataset.html>

</details>

### 51. Which of the following is a characteristic of deep learning models?

**Options:**

- **A.** They use multiple layers of neural networks
- **B.** They only work with image data
- **C.** They don't require large amounts of data
- **D.** They are always faster than traditional ML models

<details><summary>Answer</summary>

**Correct answer:** A. They use multiple layers of neural networks  

*Explanation:* Deep learning stacks many layers to learn hierarchical representations (e.g., CNNs, RNNs).  
Documentation: <https://docs.aws.amazon.com/machine-learning/latest/dg/deep-learning.html>

</details>

### 52. What is Amazon Rekognition primarily used for?

**Options:**

- **A.** Natural language processing
- **B.** Speech synthesis
- **C.** Image and video analysis
- **D.** Language translation

<details><summary>Answer</summary>

**Correct answer:** C. Image and video analysis  

*Explanation:* Rekognition detects objects, faces, text, unsafe content and more in images & video.  
Documentation: <https://docs.aws.amazon.com/rekognition/latest/dg/what-is.html>

</details>

### 53. What is Amazon SageMaker primarily used for?

**Options:**

- **A.** Data storage
- **B.** Building, training, and deploying machine learning models
- **C.** Network security
- **D.** Database management

<details><summary>Answer</summary>

**Correct answer:** B. Building, training, and deploying machine learning models  

*Explanation:* SageMaker is AWS’s end‑to‑end ML platform covering data prep to production.  
Documentation: <https://docs.aws.amazon.com/sagemaker/latest/dg/whatis.html>

</details>

### 54. Which AWS service can automatically detect anomalies in time series data?

**Options:**

- **A.** Amazon Lookout for Metrics
- **B.** Amazon Forecast
- **C.** Amazon Personalize
- **D.** Amazon Comprehend

<details><summary>Answer</summary>

**Correct answer:** A. Amazon Lookout for Metrics  

*Explanation:* Lookout for Metrics uses ML to find anomalies and root causes in KPIs with no ML experience required.  
Documentation: <https://docs.aws.amazon.com/lookoutmetrics/latest/userguide/what-is.html>

</details>

### 55. What is the purpose of hyperparameter tuning in ML?

**Options:**

- **A.** To optimize model performance by finding the best hyperparameters
- **B.** To reduce model size
- **C.** To speed up inference
- **D.** To improve data quality

<details><summary>Answer</summary>

**Correct answer:** A. To optimize model performance by finding the best hyperparameters  

*Explanation:* Choosing good hyperparameters (learning rate, depth, etc.) often has more impact than the algorithm itself.  
Documentation: <https://docs.aws.amazon.com/sagemaker/latest/dg/automatic-model-tuning.html>

</details>

### 56. Which AWS service can detect fraudulent activities in real-time?

**Options:**

- **A.** Amazon Fraud Detector
- **B.** Amazon GuardDuty
- **C.** Amazon Inspector
- **D.** Amazon Macie

<details><summary>Answer</summary>

**Correct answer:** A. Amazon Fraud Detector  

*Explanation:* Fraud Detector creates custom fraud detection models based on your historical datasets.  
Documentation: <https://docs.aws.amazon.com/frauddetector/latest/ug/what-is-afd.html>

</details>

### 57. What is Amazon Translate used for?

**Options:**

- **A.** Converting speech to text
- **B.** Translating text between different languages
- **C.** Analyzing sentiment in text
- **D.** Generating speech from text

<details><summary>Answer</summary>

**Correct answer:** B. Translating text between different languages  

*Explanation:* Translate offers neural machine translation for 75+ languages via synchronous or batch API.  
Documentation: <https://docs.aws.amazon.com/translate/latest/dg/what-is.html>

</details>

### 58. What is Amazon Kendra used for?

**Options:**

- **A.** Image recognition
- **B.** Intelligent document search
- **C.** Language translation
- **D.** Speech synthesis

<details><summary>Answer</summary>

**Correct answer:** B. Intelligent document search  

*Explanation:* Kendra lets you index disparate data sources and return precise answers to natural‑language queries.  
Documentation: <https://docs.aws.amazon.com/kendra/latest/dg/what-is-kendra.html>

</details>

### 59. What is cross-validation used for in machine learning?

**Options:**

- **A.** To increase the size of the training dataset
- **B.** To assess how well a model will generalize to new data
- **C.** To speed up model training
- **D.** To reduce the number of features

<details><summary>Answer</summary>

**Correct answer:** B. To assess how well a model will generalize to new data  

*Explanation:* K‑fold CV provides a reliable estimate of out‑of‑sample performance using only the training set.  
Documentation: <https://docs.aws.amazon.com/machine-learning/latest/dg/cross-validation.html>

</details>

### 60. Which SageMaker feature allows you to experiment with different ML algorithms without writing code?

**Options:**

- **A.** SageMaker Studio
- **B.** SageMaker Autopilot
- **C.** SageMaker Endpoints
- **D.** SageMaker Ground Truth

<details><summary>Answer</summary>

**Correct answer:** B. SageMaker Autopilot  

*Explanation:* Autopilot runs AutoML: it automatically explores preprocessors & algorithms and returns ranked models.  
Documentation: <https://docs.aws.amazon.com/sagemaker/latest/dg/autopilot.html>

</details>

### 61. What is transfer learning?

**Options:**

- **A.** Moving data between different storage systems
- **B.** Using a pre-trained model as the starting point for a new task
- **C.** Transferring models between different cloud providers
- **D.** Converting models between different formats

<details><summary>Answer</summary>

**Correct answer:** B. Using a pre-trained model as the starting point for a new task  

*Explanation:* Transfer learning lets you fine‑tune a model trained on one dataset to perform a related task with less data.  
Documentation: <https://docs.aws.amazon.com/sagemaker/latest/dg/transfer-learning.html>

</details>

### 62. Which evaluation metric is commonly used for classification problems?

**Options:**

- **A.** Mean Squared Error (MSE)
- **B.** Root Mean Square Error (RMSE)
- **C.** Accuracy
- **D.** R-squared

<details><summary>Answer</summary>

**Correct answer:** C. Accuracy  

*Explanation:* Accuracy = correct predictions / total predictions – a straightforward metric for balanced classification tasks.  
Documentation: <https://docs.aws.amazon.com/machine-learning/latest/dg/types-of-models.html>

</details>

### 63. What is the primary difference between supervised and unsupervised learning?

**Options:**

- **A.** Supervised learning uses labeled data, unsupervised learning uses unlabeled data
- **B.** Supervised learning is faster than unsupervised learning
- **C.** Supervised learning requires more computational resources
- **D.** Supervised learning can only be used for classification tasks

<details><summary>Answer</summary>

**Correct answer:** A. Supervised learning uses labeled data, unsupervised learning uses unlabeled data  

*Explanation:* In supervised learning you train on input–label pairs; unsupervised algorithms infer structure from raw inputs.  
Documentation: <https://docs.aws.amazon.com/machine-learning/latest/dg/unsupervised.html>

</details>

### 64. What is feature engineering?

**Options:**

- **A.** The process of selecting and transforming variables for machine learning models
- **B.** The process of training a model
- **C.** The process of deploying a model
- **D.** The process of collecting data

<details><summary>Answer</summary>

**Correct answer:** A. The process of selecting and transforming variables for machine learning models  

*Explanation:* Feature engineering creates informative inputs (scaling, encoding, interaction terms) that boost model performance.  
Documentation: <https://docs.aws.amazon.com/machine-learning/latest/dg/feature-engineering.html>

</details>

### 65. Which of the following best describes ensemble methods?

**Options:**

- **A.** Using multiple models together to make better predictions
- **B.** Training one very large model
- **C.** Using only the best performing model
- **D.** Combining different datasets

<details><summary>Answer</summary>

**Correct answer:** A. Using multiple models together to make better predictions  

*Explanation:* Techniques like bagging, boosting and stacking combine model outputs to improve robustness and accuracy.  
Documentation: <https://docs.aws.amazon.com/machine-learning/latest/dg/ensemble-methods.html>

</details>
