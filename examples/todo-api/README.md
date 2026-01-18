# Todo API Example

This example shows how to use Ralph to build a simple REST API for todo items.

## Stories

1. **S1: Setup project structure** - Initialize Node.js/Express
2. **S2: GET /todos** - List all todos
3. **S3: POST /todos** - Create a todo
4. **S4: PUT /todos/:id** - Update a todo
5. **S5: DELETE /todos/:id** - Delete a todo

## Expected File Structure

After Ralph completes:

```
todo-api/
├── package.json
├── server.js
├── routes/
│   └── todos.js
├── tests/
│   └── todos.test.js
├── prd.json
├── prompt.md
└── progress.txt
```

## Running This Example

```bash
cd examples/todo-api
ralph-init
# The prd.json is already set up
ralph
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /todos | List all todos |
| POST | /todos | Create a todo |
| PUT | /todos/:id | Update a todo |
| DELETE | /todos/:id | Delete a todo |

## Todo Object

```json
{
  "id": 1,
  "title": "Buy groceries",
  "completed": false
}
```
