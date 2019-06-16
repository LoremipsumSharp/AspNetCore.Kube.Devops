FROM mcr.microsoft.com/dotnet/core/aspnet:2.2
WORKDIR /app
COPY  ./src/publish  /app
ENTRYPOINT ["dotnet", "AspNetCore.Kube.Devops.dll"]