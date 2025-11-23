# Frontend Implementation Guide

Simple React frontend for CarePath demo with two tabs: Chat History and Chat.

## Overview

- **Location**: `frontend_chat/`
- **Framework**: React (Create React App or Vite)
- **Hosting**: AWS S3 + CloudFront (static site)
- **Purpose**: Demo frontend to interact with CarePath APIs

## API Endpoints Used

| Endpoint | Service | Purpose |
|----------|---------|---------|
| `GET /chat-logs` | db-api | Fetch all chat history |
| `POST /triage` | chat-api | Submit a chat query |

## Implementation Tasks

### 1. Project Setup

- [x] Create React project with Vite in `frontend_chat/`
  ```bash
  npm create vite@latest frontend_chat -- --template react
  ```
- [x] Install dependencies:
  - `react-router-dom` for tabs/routing
  - `tailwindcss`, `postcss`, `autoprefixer` for styling
- [x] Configure Tailwind CSS (using Tailwind v4 with @tailwindcss/vite plugin)
- [x] Set up basic project structure:
  ```
  frontend_chat/
  ├── src/
  │   ├── components/
  │   │   ├── ChatHistory.jsx
  │   │   ├── Chat.jsx
  │   │   └── TabNav.jsx
  │   ├── services/
  │   │   └── api.js
  │   ├── App.jsx
  │   └── main.jsx
  ├── .env.example
  ├── package.json
  └── vite.config.js
  ```
- [x] Create `.env.example` with API URL placeholders:
  ```
  VITE_DB_API_URL=http://your-db-api-url
  VITE_CHAT_API_URL=http://your-chat-api-url
  ```

### 2. API Service Layer

- [x] Create `src/services/api.js` with:
  - [x] `fetchChatLogs()` - GET request to db-api `/chat-logs`
  - [x] `submitChat(patientMrn, query)` - POST request to chat-api `/triage`
- [x] Handle API errors gracefully
- [x] Use environment variables for API URLs

### 3. Tab Navigation Component

- [x] Create `TabNav.jsx` component with two tabs:
  - "Chat History" tab
  - "Chat" tab
- [x] Use simple state or react-router for tab switching
- [x] Style tabs to show active state

### 4. Chat History Tab

- [x] Create `ChatHistory.jsx` component
- [x] On mount, fetch all chat logs from `GET /chat-logs`
- [x] Display chat logs in a list/table format showing:
  - `conversation_id`
  - `patient_mrn`
  - `started_at` (formatted date)
  - First message (query) preview
  - Response preview
- [x] Add loading state while fetching
- [x] Add error state if fetch fails
- [x] Add pagination (API supports `skip` and `limit`)

### 5. Chat Tab

- [x] Create `Chat.jsx` component with:
  - [x] Large text input for user query
  - [x] Text input for patient MRN (can default to a demo value like "P000123")
  - [x] "Submit" button
  - [x] Response display area
  - [x] "New Chat" button (appears after response)

- [x] Implement state management:
  - [x] `query` - current input text
  - [x] `patientMrn` - patient MRN input
  - [x] `response` - API response (null initially)
  - [x] `isLoading` - loading state
  - [x] `error` - error state

- [x] Implement behavior:
  - [x] On Submit: POST to `/triage`, show loading, display response
  - [x] State persists when switching tabs (keep in parent App state or context)
  - [x] "New Chat" button clears query and response, resets to initial state
  - [x] Disable Submit while loading

### 6. Styling (Tailwind CSS)

- [x] Design clean, modern UI with Tailwind:
  - [x] **Tab navigation**: Horizontal tabs with active state highlight (`border-b-2 border-blue-500`)
  - [x] **Layout**: Centered container with max-width, padding (`max-w-4xl mx-auto p-6`)
  - [x] **Chat input**: Large textarea with border, focus ring (`w-full h-32 p-4 border rounded-lg focus:ring-2`)
  - [x] **Submit button**: Primary button style (`bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded-lg`)
  - [x] **Response display**: Card with background, padding (`bg-gray-50 p-4 rounded-lg border`)
  - [x] **Chat history table**: Clean table with hover states (`divide-y hover:bg-gray-50`)
  - [x] **Loading spinner**: Animated spinner (`animate-spin`)
  - [x] **Error messages**: Red alert box (`bg-red-50 border-red-200 text-red-700`)
  - [x] **"New Chat" button**: Secondary/outline style (`border border-gray-300 hover:bg-gray-50`)

### 7. Terraform: S3 Static Hosting

- [x] Create new Terraform module: `infra/terraform/modules/frontend/`
- [x] Add resources:
  - [x] S3 bucket for static files
  - [x] S3 bucket policy for CloudFront OAI access
  - [x] CloudFront distribution for HTTPS
- [x] Add variables:
  - [x] `bucket_name`
  - [x] `environment`
- [x] Add outputs:
  - [x] `bucket_name`
  - [x] `website_url`
  - [x] `cloudfront_url`
  - [x] `cloudfront_distribution_id` (for cache invalidation)

### 8. Terraform: Wire Up Frontend Module

- [x] Add `expose_frontend` variable to demo env (default: true)
- [x] Add `frontend_bucket_name` variable to demo env
- [x] Add frontend module to `infra/terraform/envs/demo/main.tf`:
  ```hcl
  module "frontend" {
    source = "../../modules/frontend"
    count  = var.expose_frontend ? 1 : 0

    bucket_name = var.frontend_bucket_name
    environment = var.environment
  }
  ```
- [x] Add outputs for frontend URL

### 9. Build & Deploy Pipeline

- [x] Add Makefile targets:
  - [x] `frontend-install` - npm install in frontend_chat/
  - [x] `frontend-build` - npm run build
  - [x] `frontend-deploy` - build and sync to S3, invalidate CloudFront
  - [x] `frontend-dev` - run dev server
  - [x] `frontend-invalidate-cache` - invalidate CloudFront cache
- [x] Document deployment steps in `docs/deploy.md`

### 10. CORS Configuration

- [x] Verify db-api has CORS enabled (`allow_origins=["*"]` in main.py)
- [x] Chat-api already has CORS (`allow_origins=["*"]` in main.py)
- [ ] For production, restrict CORS to frontend domain

### 11. Testing
Can use playwright MCP here to check!

- [ ] Test locally:
  - [ ] Run frontend dev server
  - [ ] Point to deployed API URLs
  - [ ] Verify Chat History loads
  - [ ] Verify Chat submit/response works
  - [ ] Verify state persists across tab switches
  - [ ] Verify "New Chat" resets properly
- [ ] Test deployed:
  - [ ] Access S3/CloudFront URL
  - [ ] Verify same functionality

### 12. Documentation

- [x] Update `docs/deploy.md` with frontend deployment section
- [x] Add frontend configuration to Configuration section
- [x] Document environment variables
- [x] Add Makefile commands to command reference table

---

## API Response Formats

### GET /chat-logs Response
```json
{
  "items": [
    {
      "_id": "...",
      "conversation_id": "CONV-2024-01-15-P000123-abc12345",
      "patient_mrn": "P000123",
      "channel": "api",
      "started_at": "2024-01-15T10:30:00.000Z",
      "ended_at": "2024-01-15T10:30:05.000Z",
      "messages": [
        {"role": "user", "content": "What are my medications?", "timestamp": "..."},
        {"role": "assistant", "content": "Based on your records...", "timestamp": "..."}
      ],
      "trace_id": "TRC-..."
    }
  ],
  "total": 42,
  "skip": 0,
  "limit": 10
}
```

### POST /triage Request
```json
{
  "patient_mrn": "P000123",
  "query": "What are my current medications?"
}
```

### POST /triage Response
```json
{
  "trace_id": "TRC-2024-01-15-abc12345",
  "patient_mrn": "P000123",
  "query": "What are my current medications?",
  "llm_mode": "mock",
  "response": "Based on your medical records...",
  "conversation_id": "CONV-2024-01-15-P000123-xyz98765"
}
```

---

## Notes

- No authentication required (demo only)
- Patient MRN can be hardcoded or user-input (demo MRNs: P000001-P000050)
- Keep UI minimal - this is for demo purposes
- S3 static hosting is simple and cheap for a demo
