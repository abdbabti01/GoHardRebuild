using Microsoft.EntityFrameworkCore;

namespace GoHard.Api.Persistence;

public class GoHardDb(DbContextOptions<GoHardDb> options) : DbContext(options)
{
    public DbSet<User> Users => Set<User>();
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();
    public DbSet<Operation> Operations => Set<Operation>();
    public DbSet<TrainingContext> TrainingContexts => Set<TrainingContext>();
    public DbSet<Plan> Plans => Set<Plan>();
    public DbSet<Occasion> Occasions => Set<Occasion>();
    public DbSet<Workout> Workouts => Set<Workout>();
    public DbSet<WorkoutExercise> WorkoutExercises => Set<WorkoutExercise>();
    public DbSet<WorkoutSet> WorkoutSets => Set<WorkoutSet>();
    public DbSet<FoodEntry> FoodEntries => Set<FoodEntry>();
    public DbSet<CatalogExercise> CatalogExercises => Set<CatalogExercise>();
    public DbSet<Run> Runs => Set<Run>();
    public DbSet<BodyMetric> BodyMetrics => Set<BodyMetric>();
    public DbSet<Proposal> Proposals => Set<Proposal>();

    protected override void OnModelCreating(ModelBuilder b)
    {
        b.Entity<User>(e =>
        {
            e.HasIndex(x => x.Email).IsUnique();
            e.Property(x => x.Email).HasMaxLength(320);
            e.Property(x => x.DisplayName).HasMaxLength(80);
            e.Property(x => x.Revision).IsConcurrencyToken();
        });
        Owned<RefreshToken>(b, x => x.UserId).HasIndex(x => x.TokenHash).IsUnique();
        Owned<Operation>(b, x => x.UserId).HasKey(x => new { x.UserId, x.OperationId });
        Owned<TrainingContext>(b, x => x.UserId).HasKey(x => x.UserId);
        b.Entity<TrainingContext>().Property(x => x.Revision).IsConcurrencyToken();

        Owned<Plan>(b, x => x.UserId).Property(x => x.Revision).IsConcurrencyToken();
        b.Entity<Plan>().HasMany(x => x.Occasions).WithOne().HasForeignKey(x => x.PlanId).OnDelete(DeleteBehavior.Cascade);
        Owned<Occasion>(b, x => x.UserId);

        // Plan/occasion links never cascade into performed history.
        Owned<Workout>(b, x => x.UserId).Property(x => x.Revision).IsConcurrencyToken();
        b.Entity<Workout>().HasOne<Plan>().WithMany().HasForeignKey(x => x.PlanId).OnDelete(DeleteBehavior.SetNull);
        b.Entity<Workout>().HasOne<Occasion>().WithMany().HasForeignKey(x => x.OccasionId).OnDelete(DeleteBehavior.SetNull);
        b.Entity<Workout>().HasMany(x => x.Exercises).WithOne().HasForeignKey(x => x.WorkoutId).OnDelete(DeleteBehavior.Cascade);
        Owned<WorkoutExercise>(b, x => x.UserId).HasMany(x => x.Sets).WithOne().HasForeignKey(x => x.ExerciseId).OnDelete(DeleteBehavior.Cascade);
        Owned<WorkoutSet>(b, x => x.UserId).Property(x => x.Revision).IsConcurrencyToken();
        b.Entity<WorkoutSet>().Property(x => x.LoadKg).HasPrecision(9, 3);
        b.Entity<WorkoutSet>().HasIndex(x => x.WorkoutId);

        Owned<FoodEntry>(b, x => x.UserId).Property(x => x.Revision).IsConcurrencyToken();
        b.Entity<FoodEntry>(e =>
        {
            e.HasIndex(x => new { x.UserId, x.DayKey });
            e.Property(x => x.Calories).HasPrecision(9, 2);
            e.Property(x => x.ProteinG).HasPrecision(9, 2);
            e.Property(x => x.CarbsG).HasPrecision(9, 2);
            e.Property(x => x.FatG).HasPrecision(9, 2);
        });
        b.Entity<CatalogExercise>().HasKey(x => x.Key);

        Owned<Run>(b, x => x.UserId).Property(x => x.DistanceMeters).HasPrecision(10, 1);
        Owned<BodyMetric>(b, x => x.UserId).Property(x => x.WeightKg).HasPrecision(6, 2);
        b.Entity<BodyMetric>().Property(x => x.BodyFatPercent).HasPrecision(5, 2);
        Owned<Proposal>(b, x => x.UserId).HasOne<Plan>().WithMany().HasForeignKey(x => x.PlanId).OnDelete(DeleteBehavior.Cascade);
    }

    /// <summary>Every owned row is indexed by owner and erased with the account.</summary>
    private static Microsoft.EntityFrameworkCore.Metadata.Builders.EntityTypeBuilder<T> Owned<T>(
        ModelBuilder b, System.Linq.Expressions.Expression<Func<T, object?>> userId) where T : class
    {
        var e = b.Entity<T>();
        e.HasOne<User>().WithMany().HasForeignKey(userId).OnDelete(DeleteBehavior.Cascade);
        return e;
    }
}

/// <summary>Lets `dotnet ef migrations add` build the model without local secrets. It never connects.</summary>
public sealed class DesignTimeFactory : Microsoft.EntityFrameworkCore.Design.IDesignTimeDbContextFactory<GoHardDb>
{
    public GoHardDb CreateDbContext(string[] args) =>
        new(new DbContextOptionsBuilder<GoHardDb>().UseNpgsql("Host=design-time-only").Options);
}
