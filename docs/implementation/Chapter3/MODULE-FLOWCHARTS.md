# Chapter 3 Module Flowcharts

```mermaid
graph TD
  A[src/runtime/persistence.nim] --> B[bridge APIs]
  B --> C[reconcile]
  B --> D[snapshot/restore]
```
