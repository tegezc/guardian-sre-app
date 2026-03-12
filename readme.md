graph TD
    subgraph Client ["📱 Frontend (Mobile App)"]
        UI["UI Layer<br>(Guardian Orb Visualizer)"]
        BLoC["State Management<br>(VoiceBloc / Clean Arch)"]
        Audio["Audio Hardware<br>(Full-Duplex VoIP + AEC)"]
        
        UI <--> BLoC
        BLoC <--> Audio
    end

    subgraph Middleware ["☁️ Google Cloud Run (Backend)"]
        SocketIO["Flask + Socket.IO Server<br>(Port 8080)"]
        Buffer["Audio Chunking Buffer<br>(4KB PCM Validation)"]
        AsyncBridge["Async Session Bridge<br>(Threading ↔ Asyncio)"]
        ToolService["SRE Tool Service<br>(Service Registry)"]

        SocketIO <-->|WebSocket Stream| BLoC
        SocketIO <--> Buffer
        Buffer <--> AsyncBridge
        AsyncBridge <--> ToolService
    end

    subgraph GCP ["🌐 Google Cloud Platform (Ecosystem)"]
        Gemini["Vertex AI<br>Gemini Live API<br>(Native Audio)"]
        Logging["Cloud Logging API<br>(Real-time Error Logs)"]
        TargetServices["Target Services<br>(locasentiment-api, umkm-go-ai-api)"]

        AsyncBridge <-->|gRPC Bidirectional Stream| Gemini
        ToolService -->|"Query Log Filter"| Logging
        ToolService -->|"HTTP GET Cold Start Ping"| TargetServices
    end

    classDef mobile fill:#0b3b24,stroke:#00ff88,stroke-width:2px,color:#fff;
    classDef cloud fill:#0b1d3b,stroke:#4da6ff,stroke-width:2px,color:#fff;
    classDef google fill:#3b0b13,stroke:#ff4d4d,stroke-width:2px,color:#fff;
    
    class Client mobile;
    class Middleware cloud;
    class GCP google;