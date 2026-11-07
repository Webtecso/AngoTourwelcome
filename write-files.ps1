$files = @{
"src\app.module.ts" = @'
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AuthModule } from './auth/auth.module';
import { DriversModule } from './drivers/drivers.module';
import { TripsModule } from './trips/trips.module';
import { RealtimeModule } from './realtime/realtime.module';
import { WalletModule } from './wallet/wallet.module';
import { PaymentsModule } from './payments/payments.module';
import { PricingModule } from './pricing/pricing.module';
import { UsersModule } from './users/users.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    AuthModule,
    DriversModule,
    TripsModule,
    RealtimeModule,
    WalletModule,
    PaymentsModule,
    PricingModule,
    UsersModule,
  ],
})
export class AppModule {}
'@

"src\common\prisma\prisma.service.ts" = @'
import { Injectable, OnModuleInit } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit {
  async onModuleInit() {
    await this.$connect();
  }
}
'@

"src\common\utils\geo.util.ts" = @'
export function calculateDistanceKm(
  coord1: { latitude: number; longitude: number },
  coord2: { latitude: number; longitude: number },
): number {
  const R = 6371;
  const dLat = ((coord2.latitude - coord1.latitude) * Math.PI) / 180;
  const dLon = ((coord2.longitude - coord1.longitude) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((coord1.latitude * Math.PI) / 180) *
      Math.cos((coord2.latitude * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}
'@

"src\common\guards\jwt-auth.guard.ts" = @'
import { Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {}
'@

"src\common\decorators\current-user.decorator.ts" = @'
import { createParamDecorator, ExecutionContext } from '@nestjs/common';

export const CurrentUser = createParamDecorator(
  (data: unknown, ctx: ExecutionContext) => {
    const request = ctx.switchToHttp().getRequest();
    return request.user;
  },
);
'@

"src\users\users.service.ts" = @'
import { Injectable } from '@nestjs/common';
import { PrismaService } from '../common/prisma/prisma.service';

@Injectable()
export class UsersService {
  constructor(private prisma: PrismaService) {}

  findByPhone(phone: string) {
    return this.prisma.user.findUnique({ where: { phone } });
  }

  findById(id: string) {
    return this.prisma.user.findUnique({
      where: { id },
      include: { wallet: true },
    });
  }

  async createUser(data: {
    name: string;
    phone: string;
    email?: string;
    passwordHash: string;
  }) {
    return this.prisma.user.create({
      data: {
        ...data,
        wallet: {
          create: { balanceKz: 0, points: 0 },
        },
      },
      include: { wallet: true },
    });
  }
}
'@

"src\users\users.module.ts" = @'
import { Module } from '@nestjs/common';
import { UsersService } from './users.service';

@Module({
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}
'@

"src\auth\dto\register.dto.ts" = @'
import { IsEmail, IsOptional, IsString, MinLength, Matches } from 'class-validator';

export class RegisterDto {
  @IsString()
  @MinLength(2)
  name: string;

  @IsString()
  @Matches(/^\+?[0-9]{9,15}$/, { message: 'Telefone invalido' })
  phone: string;

  @IsOptional()
  @IsEmail()
  email?: string;

  @IsString()
  @MinLength(6)
  password: string;
}
'@

"src\auth\dto\login.dto.ts" = @'
import { IsString } from 'class-validator';

export class LoginDto {
  @IsString()
  phone: string;

  @IsString()
  password: string;
}
'@

"src\auth\strategies\jwt.strategy.ts" = @'
import { Injectable } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';
import { UsersService } from '../../users/users.service';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    configService: ConfigService,
    private usersService: UsersService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: configService.get<string>('JWT_SECRET'),
    });
  }

  async validate(payload: { sub: string; phone: string }) {
    const user = await this.usersService.findById(payload.sub);
    if (!user) return null;
    return { id: user.id, name: user.name, phone: user.phone, email: user.email };
  }
}
'@

"src\auth\auth.service.ts" = @'
import { Injectable, ConflictException, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { UsersService } from '../users/users.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';

const SALT_ROUNDS = 10;

@Injectable()
export class AuthService {
  constructor(
    private usersService: UsersService,
    private jwtService: JwtService,
  ) {}

  private buildAuthResponse(user: {
    id: string;
    name: string;
    phone: string;
    email: string | null;
    isVerified: boolean;
  }) {
    const payload = { sub: user.id, phone: user.phone };
    return {
      accessToken: this.jwtService.sign(payload),
      user: {
        id: user.id,
        name: user.name,
        phone: user.phone,
        email: user.email,
        isVerified: user.isVerified,
      },
    };
  }

  async register(dto: RegisterDto) {
    const existing = await this.usersService.findByPhone(dto.phone);
    if (existing) {
      throw new ConflictException('Ja existe uma conta com este numero de telefone');
    }

    const passwordHash = await bcrypt.hash(dto.password, SALT_ROUNDS);
    const user = await this.usersService.createUser({
      name: dto.name,
      phone: dto.phone,
      email: dto.email,
      passwordHash,
    });

    return this.buildAuthResponse(user);
  }

  async login(dto: LoginDto) {
    const user = await this.usersService.findByPhone(dto.phone);
    if (!user) {
      throw new UnauthorizedException('Telefone ou palavra-passe incorretos');
    }

    const passwordMatches = await bcrypt.compare(dto.password, user.passwordHash);
    if (!passwordMatches) {
      throw new UnauthorizedException('Telefone ou palavra-passe incorretos');
    }

    return this.buildAuthResponse(user);
  }
}
'@

"src\auth\auth.controller.ts" = @'
import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { AuthService } from './auth.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@Controller('auth')
export class AuthController {
  constructor(private authService: AuthService) {}

  @Post('register')
  register(@Body() dto: RegisterDto) {
    return this.authService.register(dto);
  }

  @Post('login')
  login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }

  @UseGuards(JwtAuthGuard)
  @Get('me')
  getProfile(@CurrentUser() user: any) {
    return user;
  }
}
'@

"src\auth\auth.module.ts" = @'
import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';
import { JwtStrategy } from './strategies/jwt.strategy';
import { UsersModule } from '../users/users.module';

@Module({
  imports: [
    UsersModule,
    PassportModule,
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        secret: configService.get<string>('JWT_SECRET'),
        signOptions: { expiresIn: configService.get<string>('JWT_EXPIRES_IN') },
      }),
    }),
  ],
  controllers: [AuthController],
  providers: [AuthService, JwtStrategy],
  exports: [AuthService],
})
export class AuthModule {}
'@

"src\drivers\dto\register-driver.dto.ts" = @'
import { IsString, IsNotEmpty } from 'class-validator';

export class RegisterDriverDto {
  @IsString() @IsNotEmpty()
  vehicleModel: string;

  @IsString() @IsNotEmpty()
  vehicleColor: string;

  @IsString() @IsNotEmpty()
  vehiclePlate: string;
}
'@

"src\drivers\dto\go-online.dto.ts" = @'
import { IsLatitude, IsLongitude } from 'class-validator';

export class GoOnlineDto {
  @IsLatitude()
  latitude: number;

  @IsLongitude()
  longitude: number;
}
'@

"src\drivers\drivers.service.ts" = @'
import { Injectable, ConflictException, NotFoundException } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { PrismaService } from '../common/prisma/prisma.service';
import { calculateDistanceKm } from '../common/utils/geo.util';

@Injectable()
export class DriversService {
  constructor(private prisma: PrismaService) {}

  async registerDriver(
    userId: string,
    data: { vehicleModel: string; vehicleColor: string; vehiclePlate: string },
  ) {
    const existing = await this.prisma.driver.findUnique({ where: { userId } });
    if (existing) {
      throw new ConflictException('Este utilizador ja esta registado como motorista');
    }

    const [driver] = await this.prisma.$transaction([
      this.prisma.driver.create({
        data: { userId, ...data },
        include: { user: true },
      }),
      this.prisma.user.update({
        where: { id: userId },
        data: { role: UserRole.DRIVER },
      }),
    ]);

    return driver;
  }

  async getByUserId(userId: string) {
    const driver = await this.prisma.driver.findUnique({ where: { userId } });
    if (!driver) throw new NotFoundException('Perfil de motorista nao encontrado');
    return driver;
  }

  async goOnline(userId: string, latitude: number, longitude: number) {
    const driver = await this.getByUserId(userId);
    return this.prisma.driver.update({
      where: { id: driver.id },
      data: { isOnline: true, currentLat: latitude, currentLng: longitude },
    });
  }

  async goOffline(userId: string) {
    const driver = await this.getByUserId(userId);
    return this.prisma.driver.update({
      where: { id: driver.id },
      data: { isOnline: false },
    });
  }

  async findNearestAvailableDriver(
    origin: { latitude: number; longitude: number },
    excludeDriverIds: string[] = [],
  ) {
    const onlineDrivers = await this.prisma.driver.findMany({
      where: {
        isOnline: true,
        currentLat: { not: null },
        currentLng: { not: null },
        id: { notIn: excludeDriverIds },
      },
      include: { user: true },
    });

    if (onlineDrivers.length === 0) return null;

    const scored = onlineDrivers.map((driver) => ({
      driver,
      score: this.calculateCompatibilityScore(driver, origin),
    }));

    scored.sort((a, b) => b.score - a.score);
    return scored[0].driver;
  }

  private calculateCompatibilityScore(
    driver: { currentLat: number | null; currentLng: number | null; rating: number; acceptedCount: number; cancelCount: number },
    origin: { latitude: number; longitude: number },
  ): number {
    const distanceKm = calculateDistanceKm(origin, {
      latitude: driver.currentLat!,
      longitude: driver.currentLng!,
    });

    const distanceScore = Math.max(0, 100 - distanceKm * 10);
    const etaMinutes = Math.max(1, Math.round(distanceKm * 2.2));
    const etaScore = Math.max(0, 100 - etaMinutes * 8);
    const ratingScore = (driver.rating / 5) * 100;

    const totalOffers = driver.acceptedCount + driver.cancelCount;
    const cancellationRate = totalOffers > 0 ? driver.cancelCount / totalOffers : 0;
    const cancellationScore = Math.max(0, 100 - cancellationRate * 100);

    const weights = {
      eta: 0.2,
      distance: 0.15,
      rating: 0.1,
      trustIndex: 0.15,
      cancellationRate: 0.1,
      specialization: 0.1,
      vehicleCondition: 0.05,
      idleTime: 0.05,
      passengerPreferences: 0.05,
      safety: 0.05,
    };

    const neutralScore = 70;

    const totalScore =
      etaScore * weights.eta +
      distanceScore * weights.distance +
      ratingScore * weights.rating +
      neutralScore * weights.trustIndex +
      cancellationScore * weights.cancellationRate +
      neutralScore * weights.specialization +
      neutralScore * weights.vehicleCondition +
      neutralScore * weights.idleTime +
      neutralScore * weights.passengerPreferences +
      neutralScore * weights.safety;

    return Math.round(totalScore);
  }

  updateLocation(driverId: string, latitude: number, longitude: number) {
    return this.prisma.driver.update({
      where: { id: driverId },
      data: { currentLat: latitude, currentLng: longitude },
    });
  }

  incrementAccepted(driverId: string) {
    return this.prisma.driver.update({
      where: { id: driverId },
      data: { acceptedCount: { increment: 1 } },
    });
  }

  incrementCancelled(driverId: string) {
    return this.prisma.driver.update({
      where: { id: driverId },
      data: { cancelCount: { increment: 1 } },
    });
  }
}
'@

"src\drivers\drivers.controller.ts" = @'
import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { DriversService } from './drivers.service';
import { RegisterDriverDto } from './dto/register-driver.dto';
import { GoOnlineDto } from './dto/go-online.dto';

@UseGuards(JwtAuthGuard)
@Controller('drivers')
export class DriversController {
  constructor(private driversService: DriversService) {}

  @Post('register')
  register(@CurrentUser() user: any, @Body() dto: RegisterDriverDto) {
    return this.driversService.registerDriver(user.id, dto);
  }

  @Post('online')
  goOnline(@CurrentUser() user: any, @Body() dto: GoOnlineDto) {
    return this.driversService.goOnline(user.id, dto.latitude, dto.longitude);
  }

  @Post('offline')
  goOffline(@CurrentUser() user: any) {
    return this.driversService.goOffline(user.id);
  }
}
'@

"src\drivers\drivers.module.ts" = @'
import { Module } from '@nestjs/common';
import { DriversService } from './drivers.service';
import { DriversController } from './drivers.controller';

@Module({
  controllers: [DriversController],
  providers: [DriversService],
  exports: [DriversService],
})
export class DriversModule {}
'@

"src\realtime\dto\join-trip.dto.ts" = @'
import { IsString } from 'class-validator';

export class JoinTripDto {
  @IsString()
  tripId: string;
}
'@

"src\realtime\dto\update-location.dto.ts" = @'
import { IsLatitude, IsLongitude, IsString } from 'class-validator';

export class UpdateLocationDto {
  @IsString()
  tripId: string;

  @IsLatitude()
  latitude: number;

  @IsLongitude()
  longitude: number;
}
'@

"src\realtime\realtime.gateway.ts" = @'
import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  MessageBody,
  ConnectedSocket,
  OnGatewayConnection,
  OnGatewayDisconnect,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../common/prisma/prisma.service';
import { DriversService } from '../drivers/drivers.service';

interface AuthenticatedSocket extends Socket {
  userId?: string;
}

@WebSocketGateway({ cors: { origin: '*' } })
export class RealtimeGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  private readonly logger = new Logger(RealtimeGateway.name);

  constructor(
    private jwtService: JwtService,
    private configService: ConfigService,
    private prisma: PrismaService,
    private driversService: DriversService,
  ) {}

  async handleConnection(client: AuthenticatedSocket) {
    try {
      const token = client.handshake.auth?.token as string;
      if (!token) throw new Error('Sem token');

      const payload = this.jwtService.verify(token, {
        secret: this.configService.get<string>('JWT_SECRET'),
      });
      client.userId = payload.sub;
      client.join(`user:${payload.sub}`);
      this.logger.log(`Socket ligado: ${client.userId}`);
    } catch {
      this.logger.warn('Ligacao de socket rejeitada: token invalido');
      client.disconnect();
    }
  }

  handleDisconnect(client: AuthenticatedSocket) {
    this.logger.log(`Socket desligado: ${client.userId ?? 'desconhecido'}`);
  }

  @SubscribeMessage('trip:join')
  async handleJoinTrip(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { tripId: string },
  ) {
    const trip = await this.prisma.trip.findUnique({
      where: { id: data.tripId },
      include: { driver: true },
    });

    if (!trip) return { error: 'Viagem nao encontrada' };

    const isPassenger = trip.passengerId === client.userId;
    const isDriver = trip.driver?.userId === client.userId;
    if (!isPassenger && !isDriver) {
      return { error: 'Sem permissao para acompanhar esta viagem' };
    }

    client.join(`trip:${data.tripId}`);
    return { joined: data.tripId };
  }

  @SubscribeMessage('trip:leave')
  handleLeaveTrip(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { tripId: string },
  ) {
    client.leave(`trip:${data.tripId}`);
  }

  @SubscribeMessage('driver:location_update')
  async handleLocationUpdate(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { tripId: string; latitude: number; longitude: number },
  ) {
    const driver = await this.prisma.driver.findUnique({ where: { userId: client.userId } });
    if (!driver) return { error: 'Apenas motoristas podem atualizar localizacao' };

    await this.driversService.updateLocation(driver.id, data.latitude, data.longitude);

    this.server.to(`trip:${data.tripId}`).emit('trip:driver_position', {
      tripId: data.tripId,
      latitude: data.latitude,
      longitude: data.longitude,
      timestamp: new Date().toISOString(),
    });
  }

  emitDriverAssigned(tripId: string, driver: unknown) {
    this.server.to(`trip:${tripId}`).emit('trip:driver_assigned', { tripId, driver });
  }

  emitStatusChanged(tripId: string, status: string) {
    this.server.to(`trip:${tripId}`).emit('trip:status_changed', { tripId, status });
  }

  emitNewTripRequestToDriver(driverUserId: string, trip: unknown) {
    this.server.to(`user:${driverUserId}`).emit('trip:new_request', trip);
  }
}
'@

"src\realtime\realtime.module.ts" = @'
import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { RealtimeGateway } from './realtime.gateway';
import { DriversModule } from '../drivers/drivers.module';

@Module({
  imports: [
    DriversModule,
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        secret: configService.get<string>('JWT_SECRET'),
      }),
    }),
  ],
  providers: [RealtimeGateway],
  exports: [RealtimeGateway],
})
export class RealtimeModule {}
'@

"src\pricing\pricing.service.ts" = @'
import { Injectable } from '@nestjs/common';
import { VehicleCategory } from '@prisma/client';
import { PrismaService } from '../common/prisma/prisma.service';
import { calculateDistanceKm } from '../common/utils/geo.util';

export interface PriceBreakdown {
  baseFare: number;
  distanceFare: number;
  timeFare: number;
  categoryAdjustment: number;
  airportSurcharge: number;
  total: number;
}

export type EconomyLevel = 'excelente' | 'normal' | 'elevado' | 'muito_elevado';

const BASE_FARE_KZ = 600;
const PER_KM_KZ = 180;
const PER_MINUTE_KZ = 20;
const AIRPORT_SURCHARGE_KZ = 200;
const AIRPORT_RADIUS_KM = 3;

const AIRPORT_COORDINATES = { latitude: -8.8584, longitude: 13.2312 };

const CATEGORY_MULTIPLIERS: Record<VehicleCategory, number> = {
  ECONOMICO: 1.0,
  CONFORTO: 1.2,
  EXECUTIVO: 1.6,
  TURISMO: 1.5,
  FAMILIA: 1.3,
  GRUPO: 1.8,
  AEROPORTO: 1.3,
  ACESSIVEL: 1.0,
};

@Injectable()
export class PricingService {
  constructor(private prisma: PrismaService) {}

  private isAirportTrip(
    origin: { latitude: number; longitude: number },
    destination: { latitude: number; longitude: number },
  ): boolean {
    return (
      calculateDistanceKm(origin, AIRPORT_COORDINATES) <= AIRPORT_RADIUS_KM ||
      calculateDistanceKm(destination, AIRPORT_COORDINATES) <= AIRPORT_RADIUS_KM
    );
  }

  calculateBreakdown(
    category: VehicleCategory,
    distanceKm: number,
    durationMinutes: number,
    origin: { latitude: number; longitude: number },
    destination: { latitude: number; longitude: number },
  ): PriceBreakdown {
    const baseFare = BASE_FARE_KZ;
    const distanceFare = Math.round(distanceKm * PER_KM_KZ);
    const timeFare = Math.round(durationMinutes * PER_MINUTE_KZ);
    const subtotal = baseFare + distanceFare + timeFare;

    const multiplier = CATEGORY_MULTIPLIERS[category];
    const categoryAdjustment = Math.round(subtotal * (multiplier - 1));

    const airportSurcharge = this.isAirportTrip(origin, destination) ? AIRPORT_SURCHARGE_KZ : 0;

    const total = Math.round((subtotal + categoryAdjustment + airportSurcharge) / 100) * 100;

    return { baseFare, distanceFare, timeFare, categoryAdjustment, airportSurcharge, total };
  }

  async calculateEconomyIndex(
    userId: string,
    currentPrice: number,
    originLabel: string,
    destinationLabel: string,
  ): Promise<{ level: EconomyLevel; averagePriceKz: number | null; percentageDiff: number | null }> {
    const pastTrips = await this.prisma.trip.findMany({
      where: {
        passengerId: userId,
        originLabel,
        destinationLabel,
        status: 'COMPLETED',
      },
      select: { priceKz: true },
      take: 20,
      orderBy: { createdAt: 'desc' },
    });

    if (pastTrips.length === 0) {
      return { level: 'normal', averagePriceKz: null, percentageDiff: null };
    }

    const averagePriceKz =
      pastTrips.reduce((sum, trip) => sum + trip.priceKz, 0) / pastTrips.length;
    const percentageDiff = Math.round(((currentPrice - averagePriceKz) / averagePriceKz) * 100);

    let level: EconomyLevel = 'normal';
    if (percentageDiff <= -10) level = 'excelente';
    else if (percentageDiff <= 10) level = 'normal';
    else if (percentageDiff <= 30) level = 'elevado';
    else level = 'muito_elevado';

    return { level, averagePriceKz: Math.round(averagePriceKz), percentageDiff };
  }
}
'@

"src\pricing\pricing.module.ts" = @'
import { Module } from '@nestjs/common';
import { PricingService } from './pricing.service';

@Module({
  providers: [PricingService],
  exports: [PricingService],
})
export class PricingModule {}
'@

"src\trips\dto\request-trip.dto.ts" = @'
import { IsEnum, IsLatitude, IsLongitude, IsNotEmpty, IsOptional, IsString } from 'class-validator';
import { VehicleCategory } from '@prisma/client';

export class RequestTripDto {
  @IsString() @IsNotEmpty()
  originLabel: string;

  @IsLatitude()
  originLat: number;

  @IsLongitude()
  originLng: number;

  @IsString() @IsNotEmpty()
  destinationLabel: string;

  @IsLatitude()
  destinationLat: number;

  @IsLongitude()
  destinationLng: number;

  @IsEnum(VehicleCategory)
  category: VehicleCategory;

  @IsOptional() @IsString()
  passengerName?: string;

  @IsOptional() @IsString()
  passengerPhone?: string;

  @IsOptional()
  scheduledFor?: Date;
}
'@

"src\trips\dto\update-trip-status.dto.ts" = @'
import { IsEnum } from 'class-validator';
import { TripStatus } from '@prisma/client';

export class UpdateTripStatusDto {
  @IsEnum(TripStatus)
  status: TripStatus;
}
'@

"src\trips\dto\quote-trip.dto.ts" = @'
import { IsLatitude, IsLongitude, IsString, IsNotEmpty } from 'class-validator';

export class QuoteTripDto {
  @IsString() @IsNotEmpty()
  originLabel: string;

  @IsLatitude()
  originLat: number;

  @IsLongitude()
  originLng: number;

  @IsString() @IsNotEmpty()
  destinationLabel: string;

  @IsLatitude()
  destinationLat: number;

  @IsLongitude()
  destinationLng: number;
}
'@

"src\trips\trips.service.ts" = @'
import { Injectable, NotFoundException } from '@nestjs/common';
import { TripStatus } from '@prisma/client';
import { PrismaService } from '../common/prisma/prisma.service';
import { DriversService } from '../drivers/drivers.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';
import { PricingService } from '../pricing/pricing.service';
import { RequestTripDto } from './dto/request-trip.dto';
import { QuoteTripDto } from './dto/quote-trip.dto';

@Injectable()
export class TripsService {
  constructor(
    private prisma: PrismaService,
    private driversService: DriversService,
    private realtimeGateway: RealtimeGateway,
    private pricingService: PricingService,
  ) {}

  async quote(dto: QuoteTripDto, category: any) {
    const distanceKm = 5;
    const durationMinutes = 15;
    return this.pricingService.calculateBreakdown(
      category,
      distanceKm,
      durationMinutes,
      { latitude: dto.originLat, longitude: dto.originLng },
      { latitude: dto.destinationLat, longitude: dto.destinationLng },
    );
  }

  async requestTrip(userId: string, dto: RequestTripDto) {
    const breakdown = await this.pricingService.calculateBreakdown(
      dto.category,
      5,
      15,
      { latitude: dto.originLat, longitude: dto.originLng },
      { latitude: dto.destinationLat, longitude: dto.destinationLng },
    );

    const trip = await this.prisma.trip.create({
      data: {
        passengerId: userId,
        originLabel: dto.originLabel,
        originLat: dto.originLat,
        originLng: dto.originLng,
        destinationLabel: dto.destinationLabel,
        destinationLat: dto.destinationLat,
        destinationLng: dto.destinationLng,
        category: dto.category,
        priceKz: breakdown.total,
        status: TripStatus.REQUESTED,
      },
      include: { driver: { include: { user: true } } },
    });

    const driver = await this.driversService.findNearestAvailableDriver({
      latitude: dto.originLat,
      longitude: dto.originLng,
    });

    if (driver) {
      await this.prisma.trip.update({
        where: { id: trip.id },
        data: { driverId: driver.id, status: TripStatus.DRIVER_ASSIGNED },
      });
      await this.driversService.incrementAccepted(driver.id);
      this.realtimeGateway.emitNewTripRequestToDriver(driver.user.id, trip);
      this.realtimeGateway.emitDriverAssigned(trip.id, driver);
    }

    return trip;
  }

  async updateStatus(tripId: string, userId: string, status: TripStatus) {
    const trip = await this.prisma.trip.findUnique({
      where: { id: tripId },
      include: { driver: { include: { user: true } } },
    });
    if (!trip) throw new NotFoundException('Viagem nao encontrada');

    const updated = await this.prisma.trip.update({
      where: { id: tripId },
      data: { status },
      include: { driver: { include: { user: true } } },
    });

    this.realtimeGateway.emitStatusChanged(tripId, status);
    if (updated.driver) {
      this.realtimeGateway.emitDriverAssigned(tripId, updated.driver);
    }

    return updated;
  }
}
'@

"src\trips\trips.controller.ts" = @'
import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { TripsService } from './trips.service';
import { RequestTripDto } from './dto/request-trip.dto';
import { QuoteTripDto } from './dto/quote-trip.dto';

@UseGuards(JwtAuthGuard)
@Controller('trips')
export class TripsController {
  constructor(private tripsService: TripsService) {}

  @Post('quote')
  quote(@Body() dto: QuoteTripDto) {
    return this.tripsService.quote(dto, 'ECONOMICO');
  }

  @Post()
  requestTrip(@CurrentUser() user: any, @Body() dto: RequestTripDto) {
    return this.tripsService.requestTrip(user.id, dto);
  }
}
'@

"src\trips\trips.module.ts" = @'
import { Module } from '@nestjs/common';
import { TripsService } from './trips.service';
import { TripsController } from './trips.controller';
import { DriversModule } from '../drivers/drivers.module';
import { RealtimeModule } from '../realtime/realtime.module';
import { PricingModule } from '../pricing/pricing.module';

@Module({
  imports: [DriversModule, RealtimeModule, PricingModule],
  controllers: [TripsController],
  providers: [TripsService],
  exports: [TripsService],
})
export class TripsModule {}
'@

"src\wallet\dto\add-funds.dto.ts" = @'
import { IsNumber, IsPositive, Max } from 'class-validator';

export class AddFundsDto {
  @IsNumber()
  @IsPositive()
  @Max(500000)
  amountKz: number;
}
'@

"src\wallet\wallet.service.ts" = @'
import { Injectable, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../common/prisma/prisma.service';

@Injectable()
export class WalletService {
  constructor(private prisma: PrismaService) {}

  async getWallet(userId: string) {
    const wallet = await this.prisma.wallet.findUnique({ where: { userId } });
    if (!wallet) throw new BadRequestException('Carteira nao encontrada');
    return wallet;
  }

  async addFunds(userId: string, amountKz: number) {
    return this.prisma.wallet.update({
      where: { userId },
      data: { balanceKz: { increment: amountKz } },
    });
  }

  async deductFunds(userId: string, amountKz: number) {
    const wallet = await this.getWallet(userId);
    if (wallet.balanceKz < amountKz) {
      throw new BadRequestException('Saldo insuficiente na carteira');
    }
    return this.prisma.wallet.update({
      where: { userId },
      data: { balanceKz: { decrement: amountKz } },
    });
  }
}
'@

"src\wallet\wallet.controller.ts" = @'
import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { WalletService } from './wallet.service';
import { AddFundsDto } from './dto/add-funds.dto';

@UseGuards(JwtAuthGuard)
@Controller('wallet')
export class WalletController {
  constructor(private walletService: WalletService) {}

  @Get()
  getWallet(@CurrentUser() user: any) {
    return this.walletService.getWallet(user.id);
  }

  @Post('add')
  addFunds(@CurrentUser() user: any, @Body() dto: AddFundsDto) {
    return this.walletService.addFunds(user.id, dto.amountKz);
  }
}
'@

"src\wallet\wallet.module.ts" = @'
import { Module } from '@nestjs/common';
import { WalletService } from './wallet.service';
import { WalletController } from './wallet.controller';

@Module({
  controllers: [WalletController],
  providers: [WalletService],
  exports: [WalletService],
})
export class WalletModule {}
'@

"src\payments\dto\pay-trip.dto.ts" = @'
import { IsEnum } from 'class-validator';
import { PaymentMethodType } from '@prisma/client';

export class PayTripDto {
  @IsEnum(PaymentMethodType)
  method: PaymentMethodType;
}
'@

"src\payments\payments.service.ts" = @'
import { Injectable, BadRequestException, ForbiddenException, ConflictException } from '@nestjs/common';
import { PaymentMethodType, TripStatus } from '@prisma/client';
import { PrismaService } from '../common/prisma/prisma.service';
import { WalletService } from '../wallet/wallet.service';
import { TripsService } from '../trips/trips.service';

@Injectable()
export class PaymentsService {
  constructor(
    private prisma: PrismaService,
    private walletService: WalletService,
    private tripsService: TripsService,
  ) {}

  async payForTrip(userId: string, tripId: string, method: PaymentMethodType) {
    const trip = await this.prisma.trip.findUnique({
      where: { id: tripId },
      include: { payment: true },
    });

    if (!trip) throw new BadRequestException('Viagem nao encontrada');
    if (trip.passengerId !== userId) {
      throw new ForbiddenException('So o passageiro pode pagar esta viagem');
    }
    if (trip.payment) {
      throw new ConflictException('Esta viagem ja foi paga');
    }
    if (trip.status !== TripStatus.IN_PROGRESS) {
      throw new BadRequestException('A viagem precisa de estar em curso para ser paga');
    }

    if (method === PaymentMethodType.CARTEIRA) {
      await this.walletService.deductFunds(userId, trip.priceKz);
    }

    const [payment] = await this.prisma.$transaction([
      this.prisma.payment.create({
        data: { tripId, method, amountKz: trip.priceKz },
      }),
    ]);

    await this.tripsService.updateStatus(tripId, userId, TripStatus.COMPLETED);

    return payment;
  }
}
'@

"src\payments\payments.controller.ts" = @'
import { Body, Controller, Param, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { PaymentsService } from './payments.service';
import { PayTripDto } from './dto/pay-trip.dto';

@UseGuards(JwtAuthGuard)
@Controller('trips/:tripId/payment')
export class PaymentsController {
  constructor(private paymentsService: PaymentsService) {}

  @Post()
  payTrip(
    @CurrentUser() user: any,
    @Param('tripId') tripId: string,
    @Body() dto: PayTripDto,
  ) {
    return this.paymentsService.payForTrip(user.id, tripId, dto.method);
  }
}
'@

"src\payments\payments.module.ts" = @'
import { Module } from '@nestjs/common';
import { PaymentsService } from './payments.service';
import { PaymentsController } from './payments.controller';
import { WalletModule } from '../wallet/wallet.module';
import { TripsModule } from '../trips/trips.module';

@Module({
  imports: [WalletModule, TripsModule],
  controllers: [PaymentsController],
  providers: [PaymentsService],
})
export class PaymentsModule {}
'@
}

foreach ($path in $files.Keys) {
    $content = $files[$path]
    Set-Content -Path $path -Value $content -Encoding UTF8
    Write-Host "Escrito: $path"
}

Write-Host ""
Write-Host "Todos os ficheiros foram gerados e corrigidos com sucesso!"