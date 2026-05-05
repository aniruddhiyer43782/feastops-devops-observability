const express = require("express");
const os = require("node:os");
const path = require("node:path");
const client = require("prom-client");
const { restaurants } = require("./mumbai-restaurants");

const register = new client.Registry();

client.collectDefaultMetrics({
  register,
  prefix: "feastops_"
});

const httpRequestDuration = new client.Histogram({
  name: "feastops_http_request_duration_seconds",
  help: "HTTP request duration in seconds",
  labelNames: ["method", "route", "status_code"],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5]
});

const ordersCreated = new client.Counter({
  name: "feastops_orders_created_total",
  help: "Total number of food delivery orders created"
});

const orderValue = new client.Histogram({
  name: "feastops_order_value_rupees",
  help: "Food delivery order value in Indian rupees",
  buckets: [100, 250, 500, 750, 1000, 1500, 2500]
});

const activeDeliveries = new client.Gauge({
  name: "feastops_active_deliveries",
  help: "Current number of active delivery orders"
});

const orderStatusChanges = new client.Counter({
  name: "feastops_order_status_changes_total",
  help: "Total number of order status changes"
});

register.registerMetric(httpRequestDuration);
register.registerMetric(ordersCreated);
register.registerMetric(orderValue);
register.registerMetric(activeDeliveries);
register.registerMetric(orderStatusChanges);

const deliveryStatuses = ["accepted", "preparing", "picked_up", "out_for_delivery", "delivered"];
const riders = ["Aman", "Priya", "Rafiq", "Neha", "Sagar"];

function getPublicUrl(pathOrUrl, fallbackBase) {
  if (pathOrUrl && /^https?:\/\//.test(pathOrUrl)) {
    return pathOrUrl;
  }

  const base = fallbackBase || process.env.PUBLIC_BASE_URL || process.env.PUBLIC_APP_URL || "http://localhost:3100";
  const pathValue = pathOrUrl || "";

  return `${base.replace(/\/$/, "")}/${pathValue.replace(/^\//, "")}`;
}

const orders = [
  {
    id: "FD-24001",
    restaurantId: "rest_101",
    customerName: "Demo Customer",
    status: "out_for_delivery",
    total: 438,
    deliveryArea: "Bandra West",
    paymentMethod: "UPI",
    rider: "Aman",
    etaMinutes: 11,
    timeline: [
      { status: "accepted", label: "Restaurant accepted the order", timestamp: "12:04" },
      { status: "preparing", label: "Kitchen started preparing", timestamp: "12:08" },
      { status: "picked_up", label: "Rider picked up the food", timestamp: "12:22" },
      { status: "out_for_delivery", label: "Order is out for delivery", timestamp: "12:31" }
    ]
  }
];

activeDeliveries.set(orders.filter((order) => order.status !== "delivered").length);

function findMenuItem(itemId) {
  for (const restaurant of restaurants) {
    const item = restaurant.menu.find((menuItem) => menuItem.id === itemId);

    if (item) {
      return { restaurant, item };
    }
  }

  return null;
}

function serializeRestaurant(restaurant) {
  return {
    id: restaurant.id,
    name: restaurant.name,
    area: restaurant.area,
    cuisine: restaurant.cuisine,
    rating: restaurant.rating,
    etaMinutes: restaurant.etaMinutes,
    priceForOne: restaurant.priceForOne,
    isOpen: restaurant.isOpen,
    image: restaurant.image,
    tags: restaurant.tags,
    featuredItems: restaurant.menu.slice(0, 2)
  };
}

function getCatalog() {
  const cuisines = [...new Set(restaurants.map((restaurant) => restaurant.cuisine))]
    .sort((first, second) => first.localeCompare(second));
  const areas = [...new Set(restaurants.map((restaurant) => restaurant.area))]
    .sort((first, second) => first.localeCompare(second));
  const items = restaurants.flatMap((restaurant) =>
    restaurant.menu.map((item) => ({
      ...item,
      restaurantId: restaurant.id,
      restaurantName: restaurant.name,
      area: restaurant.area,
      cuisine: restaurant.cuisine,
      etaMinutes: restaurant.etaMinutes,
      rating: restaurant.rating,
      isOpen: restaurant.isOpen
    }))
  );

  return {
    city: "Mumbai",
    areas,
    cuisines,
    stats: {
      restaurantCount: restaurants.length,
      menuItemCount: items.length,
      averageEtaMinutes: Math.round(restaurants.reduce((total, entry) => total + entry.etaMinutes, 0) / restaurants.length),
      openRestaurants: restaurants.filter((restaurant) => restaurant.isOpen).length
    },
    popularTags: [...new Set(items.flatMap((item) => item.tags))]
      .slice(0, 18),
    restaurants: restaurants.map(serializeRestaurant),
    items
  };
}

function normalizeSearchValue(value) {
  return String(value || "").trim().toLowerCase();
}

function getRecommendations(query) {
  const search = normalizeSearchValue(query.q);
  const area = normalizeSearchValue(query.area);
  const cuisine = normalizeSearchValue(query.cuisine);
  const type = normalizeSearchValue(query.type);
  const budget = Number(query.budget || 0);

  const scored = restaurants.map((restaurant) => {
    const matchingItems = restaurant.menu.filter((item) => {
      const searchTarget = [
        item.name,
        item.type,
        item.tags.join(" "),
        restaurant.name,
        restaurant.area,
        restaurant.cuisine,
        restaurant.tags.join(" ")
      ].join(" ").toLowerCase();

      const matchesSearch = !search || searchTarget.includes(search);
      const matchesType = !type || item.type === type;
      const matchesBudget = !budget || item.price <= budget;

      return matchesSearch && matchesType && matchesBudget;
    });

    const areaScore = area && restaurant.area.toLowerCase() === area ? 3 : 0;
    const cuisineScore = cuisine && restaurant.cuisine.toLowerCase() === cuisine ? 3 : 0;
    const itemScore = matchingItems.length * 2;
    const ratingScore = restaurant.rating;
    const etaScore = Math.max(0, 40 - restaurant.etaMinutes) / 10;
    const openScore = restaurant.isOpen ? 2 : -4;

    const sortedMatchingItems = matchingItems
      .slice()
      .sort((first, second) => second.likes - first.likes);

    let itemMatchLabel = `${matchingItems.length} matching items`;

    if (matchingItems.length === 1) {
      itemMatchLabel = "1 matching item";
    }

    return {
      ...serializeRestaurant(restaurant),
      score: Number((areaScore + cuisineScore + itemScore + ratingScore + etaScore + openScore).toFixed(2)),
      reasons: [
        areaScore ? `Delivers in ${restaurant.area}` : null,
        cuisineScore ? `${restaurant.cuisine} match` : null,
        itemScore ? itemMatchLabel : null,
        restaurant.rating >= 4.6 ? "High rating" : null,
        restaurant.etaMinutes <= 22 ? "Fast delivery" : null
      ].filter(Boolean),
      matchingItems: sortedMatchingItems
    };
  });

  return scored
    .filter((restaurant) => restaurant.matchingItems.length > 0 || (!search && !type && !budget))
    .sort((first, second) => second.score - first.score)
    .slice(0, 10);
}

function calculateOrder(items) {
  return items.reduce((summary, requestedItem) => {
    const match = findMenuItem(requestedItem.itemId);

    if (!match) {
      return summary;
    }

    const quantity = Math.max(1, Math.min(10, Number(requestedItem.quantity || 1)));
    const lineTotal = match.item.price * quantity;

    return {
      total: summary.total + lineTotal,
      items: summary.items.concat({
        id: match.item.id,
        name: match.item.name,
        restaurantId: match.restaurant.id,
        restaurantName: match.restaurant.name,
        quantity,
        price: match.item.price,
        lineTotal
      })
    };
  }, { total: 0, items: [] });
}

function getOrderProgress(status) {
  const index = deliveryStatuses.indexOf(status);

  if (index === -1) {
    return 0;
  }

  return Math.round(((index + 1) / deliveryStatuses.length) * 100);
}

function serializeOrder(order) {
  const restaurantIds = [...new Set((order.items || []).map((item) => item.restaurantId).filter(Boolean))];
  const restaurantNames = [...new Set((order.items || []).map((item) => item.restaurantName).filter(Boolean))];

  return {
    ...order,
    restaurantIds,
    restaurantNames,
    progressPercent: getOrderProgress(order.status),
    canAdvance: order.status !== "delivered"
  };
}

function nextDeliveryStatus(status) {
  const index = deliveryStatuses.indexOf(status);

  if (index === -1 || index === deliveryStatuses.length - 1) {
    return status;
  }

  return deliveryStatuses[index + 1];
}

function createApp() {
  const app = express();

  app.use(express.json());

  app.use((req, res, next) => {
    const end = httpRequestDuration.startTimer();

    res.on("finish", () => {
      end({
        method: req.method,
        route: req.route?.path || req.path,
        status_code: res.statusCode
      });
    });

    next();
  });

  app.use(express.static(path.join(__dirname, "..", "public")));

  app.get("/", (_req, res) => {
    res.sendFile(path.join(__dirname, "..", "public", "index.html"));
  });

  app.get("/health", (_req, res) => {
    res.json({
      status: "ok",
      uptimeSeconds: Math.round(process.uptime())
    });
  });

  app.get("/api/restaurants", (_req, res) => {
    res.json({
      count: restaurants.length,
      city: "Mumbai",
      restaurants: restaurants.map(serializeRestaurant)
    });
  });

  app.get("/api/catalog", (_req, res) => {
    res.json(getCatalog());
  });

  app.get("/api/recommendations", (req, res) => {
    res.json({
      city: "Mumbai",
      recommendations: getRecommendations(req.query)
    });
  });

  app.get("/api/restaurants/:id/menu", (req, res) => {
    const restaurant = restaurants.find((entry) => entry.id === req.params.id);

    if (!restaurant) {
      return res.status(404).json({ error: "Restaurant not found" });
    }

    return res.json({
      restaurantId: restaurant.id,
      restaurantName: restaurant.name,
      area: restaurant.area,
      cuisine: restaurant.cuisine,
      menu: restaurant.menu
    });
  });

  app.post("/api/orders", (req, res) => {
    const {
      customerName = "Guest",
      deliveryArea = "Bandra West",
      paymentMethod = "UPI",
      items = []
    } = req.body;
    const summary = calculateOrder(items);

    if (summary.items.length === 0) {
      return res.status(400).json({
        error: "Add at least one valid menu item to create an order"
      });
    }

    const order = {
      id: `FD-${24000 + orders.length + 1}`,
      customerName,
      status: "accepted",
      total: summary.total,
      items: summary.items,
      deliveryArea,
      paymentMethod,
      etaMinutes: 30,
      rider: "Assigning",
      timeline: [
        { status: "accepted", label: "Restaurant accepted the order", timestamp: new Date().toLocaleTimeString("en-IN", { hour: "2-digit", minute: "2-digit" }) }
      ]
    };

    orders.push(order);
    ordersCreated.inc();
    orderValue.observe(order.total);
    activeDeliveries.set(orders.filter((entry) => entry.status !== "delivered").length);

    return res.status(201).json(serializeOrder(order));
  });

  app.get("/api/orders", (_req, res) => {
    res.json({
      count: orders.length,
      orders: orders.map(serializeOrder).slice().reverse()
    });
  });

  app.get("/api/orders/:id", (req, res) => {
    const order = orders.find((entry) => entry.id === req.params.id);

    if (!order) {
      return res.status(404).json({ error: "Order not found" });
    }

    return res.json(serializeOrder(order));
  });

  app.patch("/api/orders/:id/status", (req, res) => {
    const order = orders.find((entry) => entry.id === req.params.id);

    if (!order) {
      return res.status(404).json({ error: "Order not found" });
    }

    const requestedStatus = req.body.status || order.status;

    if (!deliveryStatuses.includes(requestedStatus)) {
      return res.status(400).json({ error: "Unknown delivery status" });
    }

    order.status = requestedStatus;
    order.timeline = order.timeline || [];
    order.timeline.push({
      status: order.status,
      label: `Order moved to ${order.status.replaceAll("_", " ")}`,
      timestamp: new Date().toLocaleTimeString("en-IN", { hour: "2-digit", minute: "2-digit" })
    });
    orderStatusChanges.inc();
    activeDeliveries.set(orders.filter((entry) => entry.status !== "delivered").length);

    return res.json(serializeOrder(order));
  });

  app.post("/api/orders/:id/advance", (req, res) => {
    const order = orders.find((entry) => entry.id === req.params.id);

    if (!order) {
      return res.status(404).json({ error: "Order not found" });
    }

    const nextStatus = nextDeliveryStatus(order.status);
    order.status = nextStatus;
    order.etaMinutes = Math.max(0, order.etaMinutes - 7);
    order.rider = nextStatus === "accepted" || nextStatus === "preparing" ? "Assigning" : riders[orders.indexOf(order) % riders.length];
    order.timeline = order.timeline || [];
    order.timeline.push({
      status: nextStatus,
      label: `Order moved to ${nextStatus.replaceAll("_", " ")}`,
      timestamp: new Date().toLocaleTimeString("en-IN", { hour: "2-digit", minute: "2-digit" })
    });
    orderStatusChanges.inc();
    activeDeliveries.set(orders.filter((entry) => entry.status !== "delivered").length);

    return res.json(serializeOrder(order));
  });

  app.get("/api/devops/status", (_req, res) => {
    const appUrl = process.env.PUBLIC_APP_URL || getPublicUrl("");
    const jenkinsUrl = process.env.PUBLIC_JENKINS_URL || getPublicUrl("/job/feastops-local-ci/", process.env.PUBLIC_JENKINS_BASE_URL || "http://localhost:8081");
    const sonarUrl = process.env.PUBLIC_SONAR_URL || getPublicUrl("/dashboard?id=feastops-food-delivery-api", process.env.PUBLIC_SONAR_BASE_URL || "http://localhost:9001");
    const prometheusBaseUrl = process.env.PUBLIC_PROMETHEUS_BASE_URL || "http://localhost:9091";
    const grafanaUrl = process.env.PUBLIC_GRAFANA_URL || getPublicUrl(
      "/d/feastops-food-delivery-observability/feastops-food-delivery-observability",
      process.env.PUBLIC_GRAFANA_BASE_URL || "http://localhost:3001"
    );

    res.json({
      app: {
        status: "healthy",
        health: "/health",
        metrics: "/metrics"
      },
      deployment: {
        target: process.env.DEPLOYMENT_TARGET || "docker-compose",
        namespace: process.env.K8S_NAMESPACE || "local",
        podName: process.env.POD_NAME || os.hostname(),
        replicas: process.env.APP_REPLICAS || "1",
        serviceUrl: appUrl
      },
      ci: {
        provider: "Jenkins",
        job: "feastops-local-ci",
        url: jenkinsUrl
      },
      quality: {
        provider: "SonarQube",
        projectKey: "feastops-food-delivery-api",
        url: sonarUrl
      },
      observability: {
        prometheus: prometheusBaseUrl,
        prometheusTargets: getPublicUrl("/targets", prometheusBaseUrl),
        prometheusAlerts: getPublicUrl("/alerts", prometheusBaseUrl),
        prometheusJob: "devops-app",
        scrapeInterval: "15s",
        grafana: grafanaUrl
      }
    });
  });

  app.get("/metrics", async (_req, res) => {
    res.set("Content-Type", register.contentType);
    res.end(await register.metrics());
  });

  return app;
}

module.exports = {
  createApp,
  register
};
