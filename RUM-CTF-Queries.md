# 🏆 RUM CTF Winner Tracking Queries

## Custom RUM Events Added

### 1. CTF Challenge Winners
**Event**: `ctf_challenge_won`
**Attributes**:
- `winner`: Username who completed the challenge
- `challenge_type`: 'guardrail_ctf'
- `challenge_name`: 'Pet Recommendation Bypass'
- `user_message`: The winning prompt (first 200 chars)
- `confidence`: LLM judge confidence score
- `reasoning`: Why it was considered a win
- `completion_time`: ISO timestamp
- `session_id`: RUM session ID

### 2. Security Challenge Winners  
**Event**: `security_challenge_won`
**Attributes**:
- `winner`: Username who completed the challenge
- `challenge_type`: 'data_exfiltration'
- `challenge_name`: 'Extract Admin Email'
- `user_message`: The winning prompt
- `extracted_data`: 'admin_email'
- `completion_time`: ISO timestamp

### 3. Failed Attempts
**Event**: `ctf_challenge_attempt`
**Attributes**:
- `participant`: Username who attempted
- `success`: false
- `user_message`: The attempted prompt
- `confidence`: LLM judge confidence
- `attempt_time`: ISO timestamp

## 📊 Datadog Dashboard Queries

### Find All CTF Winners
```
@type:action @action.name:ctf_challenge_won
```

### Find All Security Winners
```
@type:action @action.name:security_challenge_won
```

### Leaderboard Query (First to Win)
```
@type:action @action.name:(ctf_challenge_won OR security_challenge_won) | sort @action.completion_time asc
```

### Success Rate Analysis
```
@type:action @action.name:ctf_challenge_attempt | stats count by @action.success
```

### Winner Timeline
```
@type:action @action.name:ctf_challenge_won | timeseries count by @action.winner
```

### Most Creative Winning Prompts
```
@type:action @action.name:ctf_challenge_won | sort @action.confidence desc
```

## 🎯 User Attributes for Filtering

### CTF Winners
- `@user.ctf_winner:true`
- `@user.ctf_status:winner`

### Security Winners  
- `@user.security_winner:true`
- `@user.security_status:winner`

## 📈 Example Dashboard Widgets

### 1. Winner Count Widget
**Query**: `@type:action @action.name:(ctf_challenge_won OR security_challenge_won)`
**Visualization**: Single Value
**Aggregation**: Count

### 2. Winners Over Time
**Query**: `@type:action @action.name:ctf_challenge_won`
**Visualization**: Timeseries
**Group by**: `@action.winner`

### 3. Challenge Success Rate
**Query**: `@type:action @action.name:ctf_challenge_attempt`
**Visualization**: Pie Chart
**Group by**: `@action.success`

### 4. Top Winners Table
**Query**: `@type:action @action.name:(ctf_challenge_won OR security_challenge_won)`
**Visualization**: Table
**Group by**: `@action.winner`
**Columns**: Count, Latest completion time

## 🔍 Advanced Queries

### Find Users Who Won Both Challenges
```
@user.ctf_winner:true @user.security_winner:true
```

### Fastest Winners (< 5 minutes from page load)
```
@type:action @action.name:ctf_challenge_won @duration:<300000
```

### Most Persistent Users (Multiple Attempts)
```
@type:action @action.name:ctf_challenge_attempt | stats count by @action.participant | sort count desc
```

## 🎮 Real-Time Monitoring

### Live Winner Feed
Create a log stream with:
```
@type:action @action.name:(ctf_challenge_won OR security_challenge_won)
```

### Challenge Activity Monitor
```
@type:action @action.name:(ctf_challenge_won OR ctf_challenge_attempt OR security_challenge_won)
```

This gives you complete visibility into who's winning your CTF challenges and how they're doing it! 🏆
