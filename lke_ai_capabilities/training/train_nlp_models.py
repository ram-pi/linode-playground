import numpy as np
from sklearn.feature_extraction.text import CountVectorizer
from sklearn.naive_bayes import MultinomialNB
from sklearn.pipeline import Pipeline
from joblib import dump

# 1. Create dummy data
X = [
    "I love this service", "This is terrible",
    "The weather is nice", "I am sad",
    "KServe is great", "Deployment failed"
]

# --- Train V1: The "Optimist" ---
# We force all labels to be "POSITIVE" so the model learns to always be happy.
y_optimist = ["POSITIVE"] * len(X)

model_v1 = Pipeline([
    ('vect', CountVectorizer()),  # Converts text to numbers
    ('clf', MultinomialNB())      # Classifier
])
model_v1.fit(X, y_optimist)
dump(model_v1, 'model-v1.joblib')
print("✅ Trained 'Optimist' model (Always says POSITIVE)")

# --- Train V2: The "Pessimist" ---
# We force all labels to be "NEGATIVE" so the model learns to always be sad.
y_pessimist = ["NEGATIVE"] * len(X)

model_v2 = Pipeline([
    ('vect', CountVectorizer()),
    ('clf', MultinomialNB())
])
model_v2.fit(X, y_pessimist)
dump(model_v2, 'model-v2.joblib')
print("✅ Trained 'Pessimist' model (Always says NEGATIVE)")
