const request = require("supertest");
const { createApp, register } = require("../src/app");

afterEach(async () => {
  await register.resetMetrics();
});

test("GET /health returns ok", async () => {
  const response = await request(createApp()).get("/health");

  expect(response.status).toBe(200);
  expect(response.body.status).toBe("ok");
});

test("GET / returns the FeastOps web UI", async () => {
  const response = await request(createApp()).get("/");

  expect(response.status).toBe(200);
  expect(response.text).toContain("Mumbai food discovery");
});

test("GET /api/restaurants returns food delivery restaurants", async () => {
  const response = await request(createApp()).get("/api/restaurants");

  expect(response.status).toBe(200);
  expect(response.body.count).toBeGreaterThan(0);
  expect(response.body.city).toBe("Mumbai");
  expect(response.body.restaurants[0]).toHaveProperty("cuisine");
  expect(response.body.restaurants[0]).toHaveProperty("area");
});

test("GET /api/catalog returns Mumbai discovery filters and menu items", async () => {
  const response = await request(createApp()).get("/api/catalog");

  expect(response.status).toBe(200);
  expect(response.body.city).toBe("Mumbai");
  expect(response.body.areas).toContain("Bandra West");
  expect(response.body.cuisines).toContain("Biryani");
  expect(response.body.stats.restaurantCount).toBeGreaterThanOrEqual(18);
  expect(response.body.items.length).toBeGreaterThan(60);
  expect(response.body.items[0]).toHaveProperty("restaurantName");
});

test("GET /api/recommendations filters by craving, area, budget, and preference", async () => {
  const response = await request(createApp())
    .get("/api/recommendations")
    .query({
      q: "vada pav",
      area: "Dadar",
      budget: 150,
      type: "veg"
    });

  expect(response.status).toBe(200);
  expect(response.body.city).toBe("Mumbai");
  expect(response.body.recommendations[0].name).toBe("Bombay Chaat Co.");
  expect(response.body.recommendations[0].matchingItems[0].name).toBe("Vada Pav Duo");
  expect(response.body.recommendations[0].reasons.length).toBeGreaterThan(0);
});

test("GET /api/recommendations supports newer Mumbai catalog searches", async () => {
  const response = await request(createApp())
    .get("/api/recommendations")
    .query({ q: "shawarma", area: "Vashi", budget: 250 });

  expect(response.status).toBe(200);
  expect(response.body.recommendations[0].name).toBe("Navi Mumbai Shawarma Stop");
  expect(response.body.recommendations[0].matchingItems[0].name).toBe("Chicken Shawarma");
});

test("GET /api/devops/status exposes CI quality and observability links", async () => {
  const response = await request(createApp()).get("/api/devops/status");

  expect(response.status).toBe(200);
  expect(response.body.deployment.target).toBe("docker-compose");
  expect(response.body.ci.provider).toBe("Jenkins");
  expect(response.body.quality.projectKey).toBe("feastops-food-delivery-api");
  expect(response.body.observability).toHaveProperty("grafana");
  expect(response.body.observability.prometheusJob).toBe("devops-app");
});

test("GET /api/restaurants/:id/menu returns menu items", async () => {
  const response = await request(createApp()).get("/api/restaurants/rest_101/menu");

  expect(response.status).toBe(200);
  expect(response.body.restaurantName).toBe("Biryani Bay");
  expect(response.body.area).toBe("Bandra West");
  expect(response.body.menu[0]).toHaveProperty("price");
});

test("GET /api/restaurants/:id/menu returns 404 for unknown restaurants", async () => {
  const response = await request(createApp()).get("/api/restaurants/missing/menu");

  expect(response.status).toBe(404);
  expect(response.body.error).toBe("Restaurant not found");
});

test("POST /api/orders creates an order and emits metrics", async () => {
  const app = createApp();
  const response = await request(app)
    .post("/api/orders")
    .send({
      customerName: "Priya",
      items: [
        { itemId: "item_101", quantity: 1 },
        { itemId: "item_104", quantity: 2 }
      ]
    });

  expect(response.status).toBe(201);
  expect(response.body.id).toMatch(/^FD-/);
  expect(response.body.total).toBe(547);
  expect(response.body.items[0].restaurantName).toBe("Biryani Bay");

  const metrics = await request(app).get("/metrics");
  expect(metrics.text).toContain("feastops_orders_created_total");
});

test("POST /api/orders ignores unknown menu items and still totals valid items", async () => {
  const response = await request(createApp())
    .post("/api/orders")
    .send({
      items: [
        { itemId: "missing_item", quantity: 1 },
        { itemId: "item_102", quantity: 2 }
      ]
    });

  expect(response.status).toBe(201);
  expect(response.body.customerName).toBe("Guest");
  expect(response.body.total).toBe(558);
  expect(response.body.items).toHaveLength(1);
});

test("POST /api/orders captures checkout context and clamps quantity", async () => {
  const response = await request(createApp())
    .post("/api/orders")
    .send({
      customerName: "Isha",
      deliveryArea: "Powai",
      paymentMethod: "Card",
      items: [{ itemId: "item_1301", quantity: 99 }]
    });

  expect(response.status).toBe(201);
  expect(response.body.deliveryArea).toBe("Powai");
  expect(response.body.paymentMethod).toBe("Card");
  expect(response.body.items[0].quantity).toBe(10);
});

test("POST /api/orders rejects empty carts", async () => {
  const response = await request(createApp())
    .post("/api/orders")
    .send({ items: [] });

  expect(response.status).toBe(400);
  expect(response.body.error).toContain("valid menu item");
});

test("GET /api/orders/:id returns seeded orders and 404 for missing orders", async () => {
  const app = createApp();

  const orders = await request(app).get("/api/orders");
  expect(orders.status).toBe(200);
  expect(orders.body.count).toBeGreaterThan(0);
  expect(orders.body.orders[0]).toHaveProperty("progressPercent");

  const existing = await request(app).get("/api/orders/FD-24001");
  expect(existing.status).toBe(200);
  expect(existing.body.status).toBe("out_for_delivery");

  const missing = await request(app).get("/api/orders/FD-99999");
  expect(missing.status).toBe(404);
  expect(missing.body.error).toBe("Order not found");
});

test("POST /api/orders/:id/advance moves an order through delivery status", async () => {
  const app = createApp();
  const created = await request(app)
    .post("/api/orders")
    .send({
      customerName: "Rohan",
      items: [{ itemId: "item_401", quantity: 1 }]
    });

  const advanced = await request(app).post(`/api/orders/${created.body.id}/advance`);

  expect(advanced.status).toBe(200);
  expect(advanced.body.status).toBe("preparing");
  expect(advanced.body.progressPercent).toBeGreaterThan(created.body.progressPercent);
  expect(advanced.body.timeline).toHaveLength(2);
  expect(advanced.body.timeline[1]).toHaveProperty("timestamp");
});

test("POST /api/orders/:id/advance returns 404 for missing orders", async () => {
  const response = await request(createApp()).post("/api/orders/FD-99999/advance");

  expect(response.status).toBe(404);
  expect(response.body.error).toBe("Order not found");
});

test("PATCH /api/orders/:id/status updates delivery status and keeps current status when omitted", async () => {
  const app = createApp();

  const delivered = await request(app)
    .patch("/api/orders/FD-24001/status")
    .send({ status: "delivered" });
  expect(delivered.status).toBe(200);
  expect(delivered.body.status).toBe("delivered");

  const unchanged = await request(app)
    .patch("/api/orders/FD-24001/status")
    .send({});
  expect(unchanged.status).toBe(200);
  expect(unchanged.body.status).toBe("delivered");
});

test("PATCH /api/orders/:id/status rejects unknown status values", async () => {
  const response = await request(createApp())
    .patch("/api/orders/FD-24001/status")
    .send({ status: "teleported" });

  expect(response.status).toBe(400);
  expect(response.body.error).toBe("Unknown delivery status");
});

test("PATCH /api/orders/:id/status returns 404 for missing orders", async () => {
  const response = await request(createApp())
    .patch("/api/orders/FD-99999/status")
    .send({ status: "delivered" });

  expect(response.status).toBe(404);
  expect(response.body.error).toBe("Order not found");
});
