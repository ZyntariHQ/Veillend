import { Injectable, UnauthorizedException } from '@nestjs/common';
import { UsersService } from '../users/users.service';
import { JwtService } from '@nestjs/jwt';
import { typedData, ec } from 'starknet';

@Injectable()
export class AuthService {
  constructor(
    private usersService: UsersService,
    private jwtService: JwtService,
  ) {}

  async generateNonce(address: string): Promise<string> {
    const nonce = Math.floor(Math.random() * 1000000000).toString();
    await this.usersService.createOrUpdate(address, { nonce });
    return nonce;
  }

  async verifySignature(address: string, signature: string[], typedDataMessage: any, publicKey: string): Promise<any> {
    const user = await this.usersService.findOne(address);
    if (!user || !user.nonce) {
      throw new UnauthorizedException('Nonce not found');
    }

    // Verify nonce
    if (typedDataMessage.message.nonce !== user.nonce) {
       throw new UnauthorizedException('Invalid nonce in message');
    }

    try {
        const messageHash = typedData.getMessageHash(typedDataMessage, address);
        
        const r = BigInt(signature[0]);
        const s = BigInt(signature[1]);
        const signatureObj = new ec.starkCurve.Signature(r, s);
        
        const isVerified = ec.starkCurve.verify(signatureObj, messageHash, publicKey);

        if (!isVerified) {
            throw new UnauthorizedException('Invalid signature');
        }
    } catch (e) {
        console.error(e);
        throw new UnauthorizedException('Signature verification failed');
    }

    return user;
  }

  async login(user: any) {
    const payload = { sub: user.address };
    return {
      access_token: this.jwtService.sign(payload),
    };
  }
}
