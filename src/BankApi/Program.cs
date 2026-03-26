using BankApi.Models;
using BankApi.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddSingleton<BankService>();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new() { Title = "Contoso Bank API", Version = "v1" });
});

var app = builder.Build();

app.UseSwagger();
app.UseSwaggerUI();

// Health
app.MapGet("/health", () => Results.Ok(new { status = "healthy", timestamp = DateTime.UtcNow }))
   .WithTags("Health");

// Customers
var customers = app.MapGroup("/api/customers").WithTags("Customers");

customers.MapGet("/", (BankService svc) => svc.GetCustomers());

customers.MapGet("/{id:guid}", (Guid id, BankService svc) =>
    svc.GetCustomer(id) is { } c ? Results.Ok(c) : Results.NotFound());

customers.MapPost("/", (CreateCustomerRequest req, BankService svc) =>
{
    var customer = svc.CreateCustomer(req);
    return Results.Created($"/api/customers/{customer.Id}", customer);
});

customers.MapDelete("/{id:guid}", (Guid id, BankService svc) =>
    svc.DeleteCustomer(id) ? Results.NoContent() : Results.NotFound());

// Accounts
var accounts = app.MapGroup("/api/accounts").WithTags("Accounts");

accounts.MapGet("/", (Guid? customerId, BankService svc) => svc.GetAccounts(customerId));

accounts.MapGet("/{id:guid}", (Guid id, BankService svc) =>
    svc.GetAccount(id) is { } a ? Results.Ok(a) : Results.NotFound());

accounts.MapPost("/", (CreateAccountRequest req, BankService svc) =>
    svc.CreateAccount(req) is { } a
        ? Results.Created($"/api/accounts/{a.Id}", a)
        : Results.BadRequest(new { error = "Customer not found" }));

accounts.MapDelete("/{id:guid}", (Guid id, BankService svc) =>
    svc.DeleteAccount(id) ? Results.NoContent() : Results.NotFound());

app.Run();
