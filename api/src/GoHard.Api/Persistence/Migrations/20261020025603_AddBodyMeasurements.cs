using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace GoHard.Api.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddBodyMeasurements : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<decimal>(
                name: "WeightKg",
                table: "BodyMetrics",
                type: "numeric(9,4)",
                precision: 9,
                scale: 4,
                nullable: true,
                oldClrType: typeof(decimal),
                oldType: "numeric(6,2)",
                oldPrecision: 6,
                oldScale: 2,
                oldNullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "ChestCm",
                table: "BodyMetrics",
                type: "numeric(8,4)",
                precision: 8,
                scale: 4,
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "LeftThighCm",
                table: "BodyMetrics",
                type: "numeric(8,4)",
                precision: 8,
                scale: 4,
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "LeftUpperArmCm",
                table: "BodyMetrics",
                type: "numeric(8,4)",
                precision: 8,
                scale: 4,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "RecordedAtUtc",
                table: "BodyMetrics",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "RightThighCm",
                table: "BodyMetrics",
                type: "numeric(8,4)",
                precision: 8,
                scale: 4,
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "RightUpperArmCm",
                table: "BodyMetrics",
                type: "numeric(8,4)",
                precision: 8,
                scale: 4,
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "WaistCm",
                table: "BodyMetrics",
                type: "numeric(8,4)",
                precision: 8,
                scale: 4,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "ChestCm",
                table: "BodyMetrics");

            migrationBuilder.DropColumn(
                name: "LeftThighCm",
                table: "BodyMetrics");

            migrationBuilder.DropColumn(
                name: "LeftUpperArmCm",
                table: "BodyMetrics");

            migrationBuilder.DropColumn(
                name: "RecordedAtUtc",
                table: "BodyMetrics");

            migrationBuilder.DropColumn(
                name: "RightThighCm",
                table: "BodyMetrics");

            migrationBuilder.DropColumn(
                name: "RightUpperArmCm",
                table: "BodyMetrics");

            migrationBuilder.DropColumn(
                name: "WaistCm",
                table: "BodyMetrics");

            migrationBuilder.AlterColumn<decimal>(
                name: "WeightKg",
                table: "BodyMetrics",
                type: "numeric(6,2)",
                precision: 6,
                scale: 2,
                nullable: true,
                oldClrType: typeof(decimal),
                oldType: "numeric(9,4)",
                oldPrecision: 9,
                oldScale: 4,
                oldNullable: true);
        }
    }
}
