import { RouterBroker } from '@api/abstract/abstract.router';
import express, { Router } from 'express';
import jwt from 'jsonwebtoken';
import path from 'path';

export class ViewsRouter extends RouterBroker {
  public readonly router: Router;

  constructor() {
    super();
    this.router = Router();

    const managerAuthEnabled = process.env?.MANAGER_AUTH === 'true';
    const apiKey = process.env?.AUTHENTICATION_API_KEY;

    if (managerAuthEnabled && apiKey) {
      this.router.use((req, res, next) => {
        const reqKey = req.headers['apikey'] as string;
        if (reqKey && reqKey === apiKey) return next();

        const authHeader = req.headers['authorization'] as string;
        if (authHeader?.startsWith('Bearer ')) {
          try {
            jwt.verify(authHeader.slice(7), apiKey);
            return next();
          } catch {
            // token invalido — continua para 401 abaixo
          }
        }

        return res.status(401).json({ error: 'Manager authentication required' });
      });
    }

    const basePath = path.join(process.cwd(), 'manager', 'dist');
    const indexPath = path.join(basePath, 'index.html');

    this.router.use(express.static(basePath));

    this.router.get('*', (req, res) => {
      res.sendFile(indexPath);
    });
  }
}
