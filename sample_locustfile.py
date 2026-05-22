from locust import HttpUser, task, between

# Target host: https://postman-echo.com
# Free, public echo API by Postman — no sign-up or API key needed

class APIUser(HttpUser):
    wait_time = between(1, 3)

    # Runs 5x — basic GET with query params echoed back
    @task(5)
    def fast_get(self):
        self.client.get("/get?user=demo&action=view", name="1. GET /get")

    # Runs 3x — returns all request headers
    @task(3)
    def get_headers(self):
        self.client.get("/headers", name="2. GET /headers")

    # Runs 2x — POST with JSON body, simulates a form submit
    @task(2)
    def post_form(self):
        self.client.post("/post", json={
            "username": "testuser",
            "action": "submit"
        }, name="3. POST /post")

    # Runs 2x — PUT request, simulates an update call
    @task(2)
    def put_update(self):
        self.client.put("/put", json={
            "id": 42,
            "status": "updated"
        }, name="4. PUT /put")

    # Runs 1x — PATCH request, simulates a partial update
    @task(1)
    def patch_update(self):
        self.client.patch("/patch", json={
            "field": "value"
        }, name="5. PATCH /patch")

    # Runs 1x — always returns HTTP 500, drives Fail Ratio above 0%
    @task(1)
    def server_error(self):
        with self.client.get(
            "/status/500",
            name="6. Server error (500)",
            catch_response=True
        ) as response:
            if response.status_code == 500:
                response.failure("Server returned 500")
