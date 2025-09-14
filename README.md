# Wilujeng Wengi Apps

A sleep tracking API application built with Ruby on Rails that allows users to track their sleep patterns, follow friends, and analyze sleep quality statistics.

## Prerequisites

Before running this project, make sure you have the following installed:

- Ruby 3.1.7 or higher
- Rails 7.2+
- Docker and Docker Compose
- Git

## Requirements

- **Ruby**: 3.1.7
- **Rails**: 7.2.2.1
- **Database**: PostgreSQL (via Docker)
- **Cache**: Redis (via Docker)
- **Testing**: Minitest

## Getting Started

### 1. Clone the Repository
```bash
git clone <repository-url>
cd wilujeng-wengi-apps
```

### 2. Environment Configuration
```bash
# Copy environment template and configure
cp .env.example .env

# Edit .env with your specific configuration
# Update DATABASE_PASSWORD and other settings as needed
```

### 3. Start Docker Services
```bash
# Start PostgreSQL and Redis containers
docker-compose up -d

# Verify services are running
docker-compose ps
```

### 4. Install Dependencies
```bash
bundle install
```

### 5. Database Setup
```bash
# Create and setup database
rails db:create
rails db:migrate

# Generate sample data (optional)
rake db:sample_data
```

### 6. Start the Application
```bash
rails server
```

The application will be available at `http://localhost:3000`

### 7. Running Tests
```bash
# Run all tests
rails test

# Run specific test files
rails test test/controllers/sleep_records_controller_test.rb
rails test test/controllers/clock_controller_test.rb
rails test test/controllers/user_followings_controller_test.rb
```

### 8. Stop Services
```bash
# Stop the Rails application (Ctrl+C)

# Stop Docker services
docker-compose down
```

## Docker Services

The application uses Docker Compose for external dependencies:

- **PostgreSQL**: Available at `localhost:5432`
  - Database: `wilujeng_wengi_apps`
  - Username: `postgres`
  - Password: `password`

- **Redis**: Available at `localhost:6379`
  - Used for caching user data and sleep statistics

```bash
# Useful Docker commands
docker-compose up -d          # Start services in background
docker-compose down           # Stop and remove containers
docker-compose logs postgres  # View PostgreSQL logs
docker-compose logs redis     # View Redis logs
docker-compose restart       # Restart all services
```

## API Collection

### Sleep Tracking Endpoints

#### 1. Clock In (Start Sleep Session)
```
POST /users/:user_id/clock_in
```
**Parameters**: `go_to_bed_at` (optional, defaults to current time)

**Example**:
```bash
curl -X POST "http://localhost:3000/users/1/clock_in" \
  -H "Content-Type: application/json" \
  -d '{"go_to_bed_at": "2025-09-13T22:00:00Z"}'
```

#### 2. Clock Out (End Sleep Session)
```
PATCH /users/:user_id/clock_out
```
**Parameters**: `wake_up_at` (optional, defaults to current time)

**Example**:
```bash
curl -X PATCH "http://localhost:3000/users/1/clock_out" \
  -H "Content-Type: application/json" \
  -d '{"wake_up_at": "2025-09-14T06:30:00Z"}'
```

### Sleep Records Endpoints

#### 3. Get User Sleep Records
```
GET /users/:user_id/sleep_records
```
**Parameters**: `page`, `limit`, `cursor` (for pagination)

**Examples**:
```bash
# Traditional pagination
curl "http://localhost:3000/users/1/sleep_records?page=1&limit=10"

# Cursor pagination
curl "http://localhost:3000/users/1/sleep_records?cursor=123&limit=10"
```

#### 4. Get Friends Sleep Records
```
GET /users/:user_id/friends_sleep_records
```
**Parameters**: `page`, `limit`

**Example**:
```bash
curl "http://localhost:3000/users/1/friends_sleep_records"
```

#### 5. Get Sleep Statistics
```
GET /users/:user_id/sleep_statistics
```
**Parameters**: `period_days` (optional, default: 30)

**Examples**:
```bash
# Last 30 days (default)
curl "http://localhost:3000/users/1/sleep_statistics"

# Last 7 days
curl "http://localhost:3000/users/1/sleep_statistics?period_days=7"

# Last 90 days
curl "http://localhost:3000/users/1/sleep_statistics?period_days=90"
```

### User Following Endpoints

#### 6. Follow User
```
POST /users/:user_id/follow/:followed_user_id
```

**Example**:
```bash
curl -X POST "http://localhost:3000/users/1/follow/2"
```

#### 7. Unfollow User
```
DELETE /users/:user_id/unfollow/:followed_user_id
```

**Example**:
```bash
curl -X DELETE "http://localhost:3000/users/1/unfollow/2"
```

## Features

- **Sleep Tracking**: Clock in/out functionality for tracking sleep sessions
- **Sleep Records**: View paginated sleep history with traditional or cursor pagination
- **Friends System**: Follow/unfollow other users
- **Social Sleep**: View friends' sleep records from the previous week
- **Sleep Analytics**: Comprehensive sleep quality statistics including:
  - Sleep duration analysis
  - Sleep patterns and consistency
  - Sleep quality scoring
  - Duration distribution
- **Caching**: Redis-powered caching for optimal performance
- **Data Validation**: Comprehensive input validation and error handling
