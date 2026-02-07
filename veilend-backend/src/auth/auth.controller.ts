import { Controller, Post, Body, Query, Get, UseGuards, Request } from '@nestjs/common';
import { AuthService } from './auth.service';
import { AuthGuard } from '@nestjs/passport';

@Controller('auth')
export class AuthController {
  constructor(private authService: AuthService) {}

  @Post('nonce')
  async getNonce(@Query('address') address: string) {
    const nonce = await this.authService.generateNonce(address);
    return { nonce };
  }

  @Post('verify')
  async verify(@Body() body: { address: string; signature: string[]; typedData: any; publicKey: string }) {
    const user = await this.authService.verifySignature(body.address, body.signature, body.typedData, body.publicKey);
    return this.authService.login(user);
  }

  @UseGuards(AuthGuard('jwt'))
  @Get('profile')
  getProfile(@Request() req) {
    return req.user;
  }
}
