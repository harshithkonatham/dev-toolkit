# AI/ML Frameworks — Setup & Reference

Updated: April 2026

---

## PyTorch 2.6

**Best for**: Deep learning research, model training, fine-tuning.

```bash
# Install (CPU)
pip install torch torchvision torchaudio

# Install (CUDA 12.1)
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

# Install (Apple Silicon / MPS)
pip install torch torchvision torchaudio
```

**Basic neural network**:
```python
import torch
import torch.nn as nn
from torch.utils.data import DataLoader, TensorDataset

# Define model
class SimpleNet(nn.Module):
    def __init__(self):
        super().__init__()
        self.layers = nn.Sequential(
            nn.Linear(784, 256),
            nn.ReLU(),
            nn.Dropout(0.2),
            nn.Linear(256, 10)
        )

    def forward(self, x):
        return self.layers(x)

# Device selection (CUDA > MPS > CPU)
device = (
    "cuda" if torch.cuda.is_available()
    else "mps" if torch.backends.mps.is_available()
    else "cpu"
)

model = SimpleNet().to(device)
optimizer = torch.optim.AdamW(model.parameters(), lr=1e-3)
criterion = nn.CrossEntropyLoss()

# Training loop
for epoch in range(10):
    for X, y in dataloader:
        X, y = X.to(device), y.to(device)
        pred = model(X)
        loss = criterion(pred, y)
        optimizer.zero_grad()
        loss.backward()
        optimizer.step()
```

---

## Hugging Face Transformers

**Best for**: Using pre-trained models (LLMs, vision, audio), fine-tuning.

```bash
pip install transformers datasets accelerate peft trl tokenizers
```

**Load and use a model**:
```python
from transformers import pipeline, AutoTokenizer, AutoModelForCausalLM
import torch

# Text generation
generator = pipeline("text-generation", model="meta-llama/Llama-3.3-70B-Instruct")
result = generator("The future of AI is", max_new_tokens=100)

# Embeddings
from sentence_transformers import SentenceTransformer
model = SentenceTransformer('all-MiniLM-L6-v2')
embeddings = model.encode(["Hello world", "How are you?"])

# Local model with 4-bit quantization (fits GPU)
from transformers import BitsAndBytesConfig

quantization_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_use_double_quant=True,
    bnb_4bit_compute_dtype=torch.bfloat16
)

tokenizer = AutoTokenizer.from_pretrained("meta-llama/Llama-3.3-70B-Instruct")
model = AutoModelForCausalLM.from_pretrained(
    "meta-llama/Llama-3.3-70B-Instruct",
    quantization_config=quantization_config,
    device_map="auto"
)
```

**Fine-tune with PEFT/LoRA**:
```python
from peft import get_peft_model, LoraConfig, TaskType
from trl import SFTTrainer, SFTConfig
from datasets import load_dataset

lora_config = LoraConfig(
    task_type=TaskType.CAUSAL_LM,
    r=16,
    lora_alpha=32,
    lora_dropout=0.05,
    target_modules=["q_proj", "v_proj"]
)

model = get_peft_model(base_model, lora_config)
model.print_trainable_parameters()

dataset = load_dataset("your-dataset")

trainer = SFTTrainer(
    model=model,
    tokenizer=tokenizer,
    train_dataset=dataset["train"],
    args=SFTConfig(
        output_dir="./output",
        num_train_epochs=3,
        per_device_train_batch_size=4,
        gradient_accumulation_steps=4,
        learning_rate=2e-4,
        fp16=True,
    ),
    dataset_text_field="text",
    max_seq_length=2048,
)

trainer.train()
trainer.save_model()
```

---

## LangChain 0.3

**Best for**: LLM application development, chains, agents, RAG pipelines.

```bash
pip install langchain langchain-core langchain-community
pip install langchain-anthropic langchain-openai langchain-ollama
pip install langgraph
```

**RAG pipeline**:
```python
from langchain_anthropic import ChatAnthropic
from langchain_ollama import OllamaEmbeddings
from langchain_community.vectorstores import Chroma
from langchain_community.document_loaders import DirectoryLoader
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain.chains import RetrievalQA

# Load documents
loader = DirectoryLoader("./docs", glob="**/*.md")
docs = loader.load()

# Split
splitter = RecursiveCharacterTextSplitter(chunk_size=1000, chunk_overlap=100)
chunks = splitter.split_documents(docs)

# Embed and store
embeddings = OllamaEmbeddings(model="nomic-embed-text")
vectorstore = Chroma.from_documents(chunks, embeddings, persist_directory="./chroma_db")

# RAG chain
llm = ChatAnthropic(model="claude-sonnet-4-6")
qa_chain = RetrievalQA.from_chain_type(
    llm=llm,
    retriever=vectorstore.as_retriever(search_kwargs={"k": 5})
)

result = qa_chain.invoke({"query": "What is the main topic?"})
```

**LangGraph agent**:
```python
from langgraph.graph import StateGraph, END
from langgraph.prebuilt import ToolNode
from langchain_anthropic import ChatAnthropic
from langchain_core.messages import HumanMessage
from typing import TypedDict, Annotated
import operator

class AgentState(TypedDict):
    messages: Annotated[list, operator.add]

llm = ChatAnthropic(model="claude-sonnet-4-6").bind_tools(tools)

def agent_node(state):
    response = llm.invoke(state["messages"])
    return {"messages": [response]}

def should_continue(state):
    last_message = state["messages"][-1]
    if last_message.tool_calls:
        return "tools"
    return END

graph = StateGraph(AgentState)
graph.add_node("agent", agent_node)
graph.add_node("tools", ToolNode(tools))
graph.set_entry_point("agent")
graph.add_conditional_edges("agent", should_continue, {"tools": "tools", END: END})
graph.add_edge("tools", "agent")

app = graph.compile()
result = app.invoke({"messages": [HumanMessage(content="Search for latest AI news")]})
```

---

## LlamaIndex 0.11

**Best for**: Document ingestion, RAG, structured data queries.

```bash
pip install llama-index llama-index-core
pip install llama-index-llms-anthropic llama-index-llms-ollama
pip install llama-index-embeddings-ollama llama-index-vector-stores-qdrant
```

**Advanced RAG**:
```python
from llama_index.core import VectorStoreIndex, SimpleDirectoryReader, Settings
from llama_index.llms.anthropic import Anthropic
from llama_index.embeddings.ollama import OllamaEmbedding
from llama_index.vector_stores.qdrant import QdrantVectorStore
from qdrant_client import QdrantClient

# Configure globally
Settings.llm = Anthropic(model="claude-sonnet-4-6")
Settings.embed_model = OllamaEmbedding(model_name="nomic-embed-text")
Settings.chunk_size = 512

# Use Qdrant as vector store
client = QdrantClient(url="http://localhost:6333")
vector_store = QdrantVectorStore(client=client, collection_name="my_docs")

# Load and index
documents = SimpleDirectoryReader("./docs").load_data()
index = VectorStoreIndex.from_documents(documents, vector_store=vector_store)

# Query with metadata filters
from llama_index.core.vector_stores import MetadataFilter, MetadataFilters

query_engine = index.as_query_engine(
    similarity_top_k=5,
    filters=MetadataFilters(
        filters=[MetadataFilter(key="category", value="tech")]
    )
)

response = query_engine.query("What are the latest trends?")
print(response)
```

---

## scikit-learn

**Best for**: Traditional ML — classification, regression, clustering.

```bash
pip install scikit-learn pandas numpy matplotlib seaborn
```

**Full ML pipeline**:
```python
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.model_selection import train_test_split, GridSearchCV
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.metrics import classification_report, confusion_matrix
import pandas as pd

df = pd.read_csv("data.csv")
X, y = df.drop("target", axis=1), df["target"]

X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

pipeline = Pipeline([
    ('scaler', StandardScaler()),
    ('model', RandomForestClassifier(n_estimators=100, random_state=42))
])

param_grid = {
    'model__n_estimators': [50, 100, 200],
    'model__max_depth': [None, 10, 20]
}

search = GridSearchCV(pipeline, param_grid, cv=5, n_jobs=-1)
search.fit(X_train, y_train)

print(classification_report(y_test, search.predict(X_test)))
```

---

## MLflow (Experiment Tracking)

```bash
pip install mlflow

# Start UI
mlflow ui    # http://localhost:5000
```

```python
import mlflow
import mlflow.sklearn

with mlflow.start_run():
    mlflow.log_param("n_estimators", 100)
    mlflow.log_param("max_depth", 10)

    model.fit(X_train, y_train)
    accuracy = model.score(X_test, y_test)

    mlflow.log_metric("accuracy", accuracy)
    mlflow.sklearn.log_model(model, "model")
```

---

## Weights & Biases (W&B)

```bash
pip install wandb
wandb login
```

```python
import wandb

wandb.init(project="my-ml-project", config={
    "learning_rate": 1e-3,
    "epochs": 10,
    "batch_size": 32
})

for epoch in range(10):
    train_loss = train_one_epoch()
    val_loss = validate()
    wandb.log({"train_loss": train_loss, "val_loss": val_loss, "epoch": epoch})

wandb.finish()
```

---

## Recommended ML Stack (2026)

| Task | Tool |
|---|---|
| Deep learning | PyTorch 2.6 + Lightning |
| LLM fine-tuning | Hugging Face + PEFT + TRL |
| LLM applications | LangChain / LlamaIndex |
| Traditional ML | scikit-learn + XGBoost |
| Experiment tracking | MLflow or W&B |
| Data processing | Pandas + Polars |
| GPU acceleration | CUDA or Apple MPS |
| Model serving | FastAPI + Triton / vLLM |
| Local inference | Ollama + vLLM |
| Vector database | Qdrant / Chroma / pgvector |
