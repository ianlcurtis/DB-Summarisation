FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 8080

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy project files for restore
COPY ["src/MedicalAgent.Api/MedicalAgent.Api.csproj", "src/MedicalAgent.Api/"]
COPY ["src/MedicalAgent.ServiceDefaults/MedicalAgent.ServiceDefaults.csproj", "src/MedicalAgent.ServiceDefaults/"]

# Restore dependencies
RUN dotnet restore "src/MedicalAgent.Api/MedicalAgent.Api.csproj"

# Copy all source files
COPY ["src/MedicalAgent.Api/", "src/MedicalAgent.Api/"]
COPY ["src/MedicalAgent.ServiceDefaults/", "src/MedicalAgent.ServiceDefaults/"]

# Build
WORKDIR /src/src/MedicalAgent.Api
RUN dotnet build -c Release -o /app/build

FROM build AS publish
RUN dotnet publish -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "MedicalAgent.Api.dll"]
