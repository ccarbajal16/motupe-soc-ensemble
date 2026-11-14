# SOC Prediction Workflow - Complete Process Flowchart
## Spatial Ensemble Machine Learning with Bootstrap Uncertainty Quantification

---

## Main Process Flow

```mermaid
flowchart TD
    A[Start: SOC Prediction Analysis] --> B[Setup & Package Loading]
    B --> C[Data Loading & Preparation]
    C --> D[Spatial Task Creation]
    D --> E[Spatial Cross-Validation Setup]
    E --> F[Model Definition & Training]
    F --> G[Ensemble Creation & Weighting]
    G --> H[Bootstrap Uncertainty Analysis]
    H --> I[Raster Predictions Generation]
    I --> J[Performance Analysis & Visualization]
    J --> K[Results Export & Reporting]
    K --> L[End: Complete Analysis]

    %% Styling
    classDef startEnd fill:#e1f5fe,stroke:#01579b,stroke-width:3px
    classDef process fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef data fill:#e8f5e8,stroke:#1b5e20,stroke-width:2px
    classDef analysis fill:#fff3e0,stroke:#e65100,stroke-width:2px
    
    class A,L startEnd
    class B,C,D,E,F,G,I,J,K process
    class H analysis
```

---

## Detailed Process Flow

```mermaid
flowchart TD
    %% Setup Phase
    A[🚀 Start Analysis] --> B[📦 Load Required Packages<br/>mlr3, terra, sf, ggplot2, etc.]
    B --> B1[⚙️ Setup Parallel Processing<br/>detectCores - 1, max 8 cores]
    B1 --> C[📁 Load Input Data]

    %% Data Loading Phase
    C --> C1[🗺️ Stack Predictor Rasters<br/>from predictors/ folder]
    C1 --> C2[📊 Load Soil Data<br/>suelos_motupe_model.gpkg]
    C2 --> C3[🏞️ Load Study Area<br/>borde_motupe.gpkg]
    C3 --> C4[✂️ Crop & Mask Predictors<br/>to study area boundary]
    C4 --> C5[🔗 Extract Predictor Values<br/>at soil sample locations]

    %% Task Creation Phase
    C5 --> D[📋 Create Spatial ML Task<br/>mlr3spatial::as_task_regr_st]
    D --> D1[⚖️ Scale Features<br/>po_scale preprocessing]
    D1 --> E[🗂️ Spatial Cross-Validation<br/>spcv_block: 5 folds, 3x3 grid]

    %% Visualization
    E --> E1[🎨 Create CV Visualization<br/>ggplot2 + base R fallback]
    E1 --> F[🤖 Define ML Models]

    %% Model Definition Phase
    F --> F1[🧠 SVM Model<br/>regr.svm: radial kernel]
    F1 --> F2[🔗 ANN Model<br/>regr.nnet: 10 neurons]
    F2 --> F3[🌳 Random Forest<br/>regr.ranger: 500 trees]
    F3 --> F4[⚡ XGBoost<br/>regr.xgboost: 100 rounds]

    %% Spatial CV Phase
    F4 --> G[🔄 Spatial Cross-Validation<br/>Sequential model training]
    G --> G1[📊 SVM Spatial CV<br/>RMSE, MAE, R²]
    G --> G2[📊 ANN Spatial CV<br/>RMSE, MAE, R²]
    G --> G3[📊 RF Spatial CV<br/>RMSE, MAE, R²]
    G --> G4[📊 XGBoost Spatial CV<br/>RMSE, MAE, R²]

    %% Ensemble Phase
    G1 --> H[⚖️ Calculate Ensemble Weights]
    G2 --> H
    G3 --> H
    G4 --> H
    H --> H1[🎯 Performance-Based Weights<br/>R² normalized weights]
    H1 --> H2[🔄 Train Final Models<br/>on complete dataset]

    %% Feature Importance
    H2 --> I1[🎯 Extract Feature Importance<br/>RF: Gini impurity]
    I1 --> I2[🎯 Extract Feature Importance<br/>XGBoost: information gain]
    I2 --> I3[📊 Create Importance Plots<br/>Individual + combined]

    %% Bootstrap Analysis
    I3 --> J[🔄 Bootstrap Uncertainty Analysis<br/>10 iterations, sequential processing]
    J --> J1[🎲 Bootstrap Sampling<br/>Random resampling with replacement]
    J1 --> J2[🤖 Train Simplified Models<br/>LM, RF, Tree ensemble]
    J2 --> J3[🗺️ Generate Bootstrap Predictions<br/>Spatial raster predictions]
    J3 --> J4[✅ Spatial Validation<br/>Extent, CRS, NA checks]
    J4 --> J5[📊 Stack Valid Predictions<br/>Min 5 valid predictions required]
    J5 --> J6[📈 Calculate Uncertainty Metrics<br/>SD, CV, PI90, Quantiles]

    %% Raster Predictions
    J6 --> K[🗺️ Generate Final Predictions]
    K --> K1[🧠 SVM Raster Prediction]
    K --> K2[🔗 ANN Raster Prediction]
    K --> K3[🌳 RF Raster Prediction]  
    K --> K4[⚡ XGBoost Raster Prediction]
    K1 --> K5[⚖️ Ensemble Average<br/>(SVM+ANN+RF+XGB)/4]
    K2 --> K5
    K3 --> K5
    K4 --> K5
    K5 --> K6[🎯 Weighted Ensemble<br/>Performance-based weights]

    %% Performance Analysis
    K6 --> L[📊 Performance Analysis]
    L --> L1[📈 Observed vs Predicted<br/>Scatter plots for all models]
    L1 --> L2[📊 CV Metrics Comparison<br/>RMSE, MAE, R² visualization]
    L2 --> L3[🎯 Ensemble Weights Plot<br/>Weight distribution analysis]
    L3 --> L4[🔄 Uncertainty Visualization<br/>Bootstrap maps and statistics]

    %% Output Generation
    L4 --> M[💾 Export Results]
    M --> M1[🗺️ Save Prediction Rasters<br/>Individual + ensemble TIFs]
    M1 --> M2[📊 Save Uncertainty Rasters<br/>Bootstrap statistics TIFs]
    M2 --> M3[🎨 Save Visualizations<br/>Plots and maps PNG files]
    M3 --> M4[💾 Save Model Objects<br/>RDS files for reuse]
    M4 --> M5[📄 Generate Reports<br/>Markdown comprehensive report]

    %% Cleanup
    M5 --> N[🧹 Memory Cleanup]
    N --> N1[🗑️ Clear Bootstrap Objects<br/>Free memory]
    N1 --> N2[🔌 Stop Parallel Cluster<br/>Clean shutdown]
    N2 --> O[✅ Analysis Complete]

    %% Error Handling Branches
    F1 --> F1E[❌ SVM Fallback<br/>regr.lm if SVM fails]
    F2 --> F2E[❌ ANN Fallback<br/>regr.lm if nnet fails]
    F3 --> F3E[❌ RF Fallback<br/>regr.rpart if ranger fails]
    F4 --> F4E[❌ XGB Fallback<br/>regr.rpart if xgboost fails]
    
    J3 --> J3E[❌ Bootstrap Fallback<br/>Mean SOC if prediction fails]
    
    E1 --> E1E[❌ Viz Fallback<br/>Base R if ggplot2 fails]

    %% Styling
    classDef startEnd fill:#e1f5fe,stroke:#01579b,stroke-width:3px,color:#000
    classDef setup fill:#f3e5f5,stroke:#4a148c,stroke-width:2px,color:#000
    classDef data fill:#e8f5e8,stroke:#1b5e20,stroke-width:2px,color:#000
    classDef model fill:#fff3e0,stroke:#e65100,stroke-width:2px,color:#000
    classDef analysis fill:#ffebee,stroke:#c62828,stroke-width:2px,color:#000
    classDef output fill:#f1f8e9,stroke:#33691e,stroke-width:2px,color:#000
    classDef error fill:#fce4ec,stroke:#ad1457,stroke-width:1px,color:#000
    
    class A,O startEnd
    class B,B1,N,N1,N2 setup
    class C,C1,C2,C3,C4,C5,D,D1 data
    class E,E1,F,F1,F2,F3,F4,G,G1,G2,G3,G4,H,H1,H2 model
    class I1,I2,I3,J,J1,J2,J3,J4,J5,J6,K,K1,K2,K3,K4,K5,K6,L,L1,L2,L3,L4 analysis
    class M,M1,M2,M3,M4,M5 output
    class F1E,F2E,F3E,F4E,J3E,E1E error
```

---

## Data Flow Architecture

```mermaid
flowchart LR
    %% Input Data
    subgraph "Input Data"
        A1[📁 predictors/<br/>13 raster files]
        A2[📊 data/suelos_motupe_model.gpkg<br/>Soil samples with SOC]
        A3[🗺️ data/borde_motupe.gpkg<br/>Study area boundary]
    end

    %% Processing Pipeline
    subgraph "Data Processing"
        B1[🔗 Raster Stacking<br/>→ predictors.tif]
        B2[✂️ Crop & Mask<br/>to study area]
        B3[📊 Extract at Points<br/>Predictors + SOC]
        B4[⚖️ Feature Scaling<br/>Standardization]
    end

    %% Model Training
    subgraph "Model Training"
        C1[🧠 SVM<br/>Radial Kernel]
        C2[🔗 ANN<br/>10 Neurons]
        C3[🌳 Random Forest<br/>500 Trees]
        C4[⚡ XGBoost<br/>100 Rounds]
    end

    %% Validation & Ensemble
    subgraph "Validation & Ensemble"
        D1[🗂️ Spatial CV<br/>5-fold spcv_block]
        D2[⚖️ Performance Weighting<br/>R² based weights]
        D3[🎯 Ensemble Models<br/>Average + Weighted]
    end

    %% Bootstrap Analysis
    subgraph "Bootstrap Analysis"
        E1[🎲 Bootstrap Sampling<br/>10 iterations]
        E2[🤖 Simplified Models<br/>LM + RF + Tree]
        E3[📊 Uncertainty Metrics<br/>SD, CV, PI90]
    end

    %% Final Outputs
    subgraph "Outputs"
        F1[🗺️ Prediction Rasters<br/>Individual + Ensemble]
        F2[📊 Uncertainty Rasters<br/>Bootstrap Statistics]
        F3[🎨 Visualizations<br/>Performance + Importance]
        F4[📄 Reports<br/>Markdown + CSV]
    end

    %% Flow connections
    A1 --> B1
    A2 --> B3
    A3 --> B2
    B1 --> B2 --> B3 --> B4
    
    B4 --> C1 & C2 & C3 & C4
    C1 & C2 & C3 & C4 --> D1
    D1 --> D2 --> D3
    
    D3 --> E1 --> E2 --> E3
    
    C1 & C2 & C3 & C4 --> F1
    D3 --> F1
    E3 --> F2
    D1 --> F3
    E3 --> F4

    %% Styling
    classDef input fill:#e3f2fd,stroke:#0277bd,stroke-width:2px
    classDef process fill:#f1f8e9,stroke:#689f38,stroke-width:2px
    classDef model fill:#fff3e0,stroke:#f57c00,stroke-width:2px
    classDef analysis fill:#fce4ec,stroke:#c2185b,stroke-width:2px
    classDef output fill:#e8f5e8,stroke:#388e3c,stroke-width:2px
    
    class A1,A2,A3 input
    class B1,B2,B3,B4 process
    class C1,C2,C3,C4 model
    class D1,D2,D3,E1,E2,E3 analysis
    class F1,F2,F3,F4 output
```

---

## Model Performance & Uncertainty Pipeline

```mermaid
flowchart TD
    %% Input
    A[📊 Training Data<br/>SOC + Predictors] --> B[🗂️ Spatial CV Setup<br/>5-fold spcv_block]
    
    %% Cross-Validation
    B --> B1[📁 Fold 1] 
    B --> B2[📁 Fold 2]
    B --> B3[📁 Fold 3] 
    B --> B4[📁 Fold 4]
    B --> B5[📁 Fold 5]
    
    %% Model Training per Fold
    B1 --> C1[🤖 Train Models<br/>SVM, ANN, RF, XGB]
    B2 --> C2[🤖 Train Models<br/>SVM, ANN, RF, XGB]
    B3 --> C3[🤖 Train Models<br/>SVM, ANN, RF, XGB]
    B4 --> C4[🤖 Train Models<br/>SVM, ANN, RF, XGB]
    B5 --> C5[🤖 Train Models<br/>SVM, ANN, RF, XGB]
    
    %% Performance Aggregation
    C1 --> D[📊 Aggregate CV Metrics<br/>Mean RMSE, MAE, R²]
    C2 --> D
    C3 --> D
    C4 --> D
    C5 --> D
    
    %% Ensemble Weighting
    D --> E[⚖️ Calculate Weights<br/>R² normalized weights]
    E --> E1[🎯 SVM: 41.3%<br/>🌳 RF: 36.0%<br/>⚡ XGB: 16.7%<br/>🔗 ANN: 6.1%]
    
    %% Final Model Training
    E1 --> F[🏁 Train Final Models<br/>on complete dataset]
    F --> F1[🧠 Final SVM Model]
    F --> F2[🔗 Final ANN Model]
    F --> F3[🌳 Final RF Model]
    F --> F4[⚡ Final XGB Model]
    
    %% Bootstrap Uncertainty
    F --> G[🔄 Bootstrap Analysis<br/>10 iterations]
    G --> G1[🎲 Bootstrap Sample 1<br/>Random resample + train]
    G --> G2[🎲 Bootstrap Sample 2<br/>Random resample + train]
    G --> G3[🎲 ...</br>...]
    G --> G10[🎲 Bootstrap Sample 10<br/>Random resample + train]
    
    %% Bootstrap Predictions
    G1 --> H1[🗺️ Prediction 1]
    G2 --> H2[🗺️ Prediction 2]
    G3 --> H3[🗺️ ...]
    G10 --> H10[🗺️ Prediction 10]
    
    %% Uncertainty Calculation
    H1 --> I[📊 Stack & Calculate<br/>Uncertainty Metrics]
    H2 --> I
    H3 --> I
    H10 --> I
    
    I --> I1[📈 Standard Deviation<br/>0.007 - 3.112]
    I --> I2[📊 Coefficient of Variation<br/>1.07% - 232.5%]
    I --> I3[📉 90% Prediction Intervals<br/>0.019 - 8.548]
    
    %% Final Outputs
    F1 --> J[🗺️ Individual Predictions]
    F2 --> J
    F3 --> J
    F4 --> J
    
    E1 --> K[🎯 Ensemble Predictions<br/>Average + Weighted]
    
    I1 --> L[📊 Uncertainty Maps]
    I2 --> L
    I3 --> L

    %% Styling
    classDef data fill:#e3f2fd,stroke:#1976d2,stroke-width:2px
    classDef cv fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    classDef model fill:#fff3e0,stroke:#f57c00,stroke-width:2px
    classDef bootstrap fill:#ffebee,stroke:#d32f2f,stroke-width:2px
    classDef output fill:#e8f5e8,stroke:#388e3c,stroke-width:2px
    
    class A,B data
    class B1,B2,B3,B4,B5,C1,C2,C3,C4,C5,D cv
    class E,E1,F,F1,F2,F3,F4 model
    class G,G1,G2,G3,G10,H1,H2,H3,H10,I,I1,I2,I3 bootstrap
    class J,K,L output
```

---

## Error Handling & Fallback Strategy

```mermaid
flowchart TD
    %% Main Process with Error Handling
    A[🚀 Start Process] --> B{📦 Package Loading}
    B -->|Success| C[📊 Data Loading]
    B -->|Fail| B1[❌ Install Missing Packages<br/>Auto-install & retry]
    B1 --> C
    
    C --> C1{🗺️ Raster Loading}
    C1 -->|Success| D[🤖 Model Definition]
    C1 -->|Fail| C2[❌ Create Predictors Folder<br/>Stack available rasters]
    C2 --> D
    
    D --> D1{🧠 SVM Model}
    D1 -->|Success| D2{🔗 ANN Model}
    D1 -->|Fail| D1E[⚠️ Fallback to regr.lm]
    D1E --> D2
    
    D2 -->|Success| D3{🌳 RF Model}
    D2 -->|Fail| D2E[⚠️ Fallback to regr.lm]
    D2E --> D3
    
    D3 -->|Success| D4{⚡ XGB Model}
    D3 -->|Fail| D3E[⚠️ Fallback to regr.rpart]
    D3E --> D4
    
    D4 -->|Success| E[🔄 Spatial CV]
    D4 -->|Fail| D4E[⚠️ Fallback to regr.rpart]
    D4E --> E
    
    E --> E1{🎨 CV Visualization}
    E1 -->|Success| F[🔄 Bootstrap Analysis]
    E1 -->|Fail| E2[⚠️ Base R Fallback Plot]
    E2 --> F
    
    F --> F1{🎲 Bootstrap Iteration}
    F1 -->|Success| F2[📊 Stack Predictions]
    F1 -->|Fail| F1E[⚠️ Exclude Failed Iteration<br/>Continue with valid ones]
    F1E --> F2
    
    F2 --> F3{📊 Min 5 Valid Predictions?}
    F3 -->|Yes| G[📈 Calculate Uncertainty]
    F3 -->|No| F4[⚠️ Create Fallback Uncertainty<br/>10% CV estimates]
    F4 --> G
    
    G --> G1{🗺️ Raster Predictions}
    G1 -->|Success| H[💾 Save Results]
    G1 -->|Fail| G2[⚠️ Create Dummy Rasters<br/>NA values with same extent]
    G2 --> H
    
    H --> I[✅ Analysis Complete]

    %% Parallel Processing Error Handling
    subgraph "Parallel Processing"
        P1[🔧 Setup Cluster] --> P2{⚡ Cluster Success?}
        P2 -->|Success| P3[🔄 Parallel Execution]
        P2 -->|Fail| P4[⚠️ Sequential Fallback]
        P3 --> P5[🔌 Cleanup Cluster]
        P4 --> P5
    end

    %% Memory Management
    subgraph "Memory Management"
        M1[🧠 Monitor Memory] --> M2{💾 Memory Available?}
        M2 -->|Yes| M3[✅ Continue Processing]
        M2 -->|No| M4[🗑️ Garbage Collection<br/>Free unused objects]
        M4 --> M5[⚠️ Reduce Bootstrap Iterations<br/>if necessary]
        M5 --> M3
    end

    %% Quality Control
    subgraph "Quality Control"
        Q1[📊 Validate Outputs] --> Q2{✅ Output Quality OK?}
        Q2 -->|Yes| Q3[✅ Accept Results]
        Q2 -->|No| Q4[⚠️ Flag Quality Issues<br/>Add warnings to report]
        Q4 --> Q3
    end

    %% Styling
    classDef process fill:#e3f2fd,stroke:#1976d2,stroke-width:2px
    classDef decision fill:#fff3e0,stroke:#f57c00,stroke-width:2px
    classDef error fill:#ffebee,stroke:#d32f2f,stroke-width:2px
    classDef success fill:#e8f5e8,stroke:#388e3c,stroke-width:2px
    classDef warning fill:#fff8e1,stroke:#f9a825,stroke-width:2px
    
    class A,C,D,E,F,G,H,I,P1,P3,P5,M1,M3,Q1 process
    class B,C1,D1,D2,D3,D4,E1,F1,F3,G1,P2,M2,Q2 decision
    class B1,C2,D1E,D2E,D3E,D4E,E2,F1E,F4,G2,P4,M4,Q4 error
    class I,Q3 success
    class M5 warning
```

---

## File Output Structure

```mermaid
flowchart LR
    %% Input Files
    subgraph "Input Files"
        I1[📁 predictors/<br/>BD.tif, Clay.tif, pH.tif<br/>EVI.tif, GNDVI.tif, etc.]
        I2[📊 data/<br/>suelos_motupe_model.gpkg<br/>borde_motupe.gpkg]
    end

    %% Processing
    I1 --> P[🔄 Analysis Process]
    I2 --> P

    %% Output Structure
    P --> O1[📁 outputs/]
    P --> O2[📁 models/]
    P --> O3[📁 plots/]

    %% Outputs Detail
    subgraph "outputs/"
        O1A[🗺️ Prediction Rasters<br/>*_prediction_spatial_cv.tif<br/>ensemble_*_spatial_cv.tif]
        O1B[📊 Uncertainty Rasters<br/>bootstrap_*_spatial_cv.tif<br/>uncertainty_stack_spatial_cv.tif]
        O1C[📄 Reports & Data<br/>spatial_cv_report.md<br/>*_feature_importance.csv<br/>uncertainty_statistics.csv]
        O1D[🎨 CV Visualization<br/>spatial_cv_partitioning.png]
    end

    %% Models Detail
    subgraph "models/"
        O2A[🧠 Trained Models<br/>svm_model_spatial_cv.RDS<br/>ann_model_spatial_cv.RDS<br/>rf_model_spatial_cv.RDS<br/>xgb_model_spatial_cv.RDS]
        O2B[⚖️ Preprocessor<br/>po_scale_spatial_cv.RDS]
    end

    %% Plots Detail
    subgraph "plots/"
        O3A[📊 Performance Plots<br/>*_observed_vs_predicted.png<br/>spatial_cv_*_comparison.png]
        O3B[🎯 Feature Importance<br/>*_feature_importance.png<br/>combined_feature_importance.png]
        O3C[🎨 Ensemble Analysis<br/>ensemble_weights_visualization.png]
        O3D[📈 Uncertainty Maps<br/>bootstrap_uncertainty_maps.png]
    end

    O1 --> O1A & O1B & O1C & O1D
    O2 --> O2A & O2B  
    O3 --> O3A & O3B & O3C & O3D

    %% Styling
    classDef input fill:#e3f2fd,stroke:#1976d2,stroke-width:2px
    classDef process fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    classDef folder fill:#fff3e0,stroke:#f57c00,stroke-width:2px
    classDef files fill:#e8f5e8,stroke:#388e3c,stroke-width:2px
    
    class I1,I2 input
    class P process
    class O1,O2,O3 folder
    class O1A,O1B,O1C,O1D,O2A,O2B,O3A,O3B,O3C,O3D files
```

This comprehensive flowchart documentation shows:
1. **Main Process Flow** - High-level overview
2. **Detailed Process Flow** - Step-by-step with error handling
3. **Data Flow Architecture** - How data moves through the system
4. **Model Performance Pipeline** - CV and uncertainty analysis
5. **Error Handling Strategy** - Fallback mechanisms
6. **File Output Structure** - What gets generated

The flowcharts can be rendered in any Markdown viewer that supports Mermaid diagrams (GitHub, GitLab, many IDEs, etc.).