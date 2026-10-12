# GoHard rebuild API. Build context: the api/ folder.
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY global.json Directory.Build.props ./
COPY src/GoHard.Api/GoHard.Api.csproj src/GoHard.Api/
RUN dotnet restore src/GoHard.Api/GoHard.Api.csproj
COPY src/GoHard.Api/ src/GoHard.Api/
RUN dotnet publish src/GoHard.Api/GoHard.Api.csproj -c Release -o /app --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
COPY --from=build /app .
ENV ASPNETCORE_ENVIRONMENT=Production
# The host supplies PORT, DATABASE_URL and GOHARD_Auth__SigningKey. Nothing secret is baked into the image.
# Schema changes are an explicit step (see railway.json preDeployCommand); starting the API never migrates.
ENTRYPOINT ["dotnet", "GoHard.Api.dll"]
