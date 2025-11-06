# MindLock Admin Dashboard Guide 📊

## Overview

Complete guide for building the React-based admin dashboard for managing donations, generating reports, and monitoring MindLock analytics.

---

## Project Setup

### 1. Initialize React Project

```bash
# Create new React project with Vite
npm create vite@latest mindlock-admin -- --template react-ts
cd mindlock-admin

# Install dependencies
npm install
npm install @tanstack/react-query axios
npm install react-router-dom
npm install recharts lucide-react
npm install @headlessui/react @heroicons/react
npm install clsx tailwind-merge
npm install react-hook-form @hookform/resolvers zod
npm install date-fns

# Install dev dependencies
npm install -D tailwindcss postcss autoprefixer
npm install -D @types/node
npx tailwindcss init -p
```

### 2. Project Structure

```bash
src/
├── components/
│   ├── ui/              # Reusable UI components
│   ├── layout/          # Layout components
│   ├── charts/          # Chart components
│   └── forms/           # Form components
├── pages/
│   ├── Dashboard.tsx
│   ├── Reports.tsx
│   ├── Charities.tsx
│   ├── Users.tsx
│   └── Login.tsx
├── hooks/               # Custom React hooks
├── services/            # API services
├── types/               # TypeScript types
├── utils/               # Utility functions
└── App.tsx
```

### 3. Tailwind Configuration

```javascript
// tailwind.config.js
/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          50: '#eff6ff',
          500: '#3b82f6',
          600: '#2563eb',
          700: '#1d4ed8',
        }
      }
    },
  },
  plugins: [],
}
```

---

## Authentication & API Setup

### 1. API Service

```typescript
// src/services/api.ts
import axios, { AxiosInstance, AxiosResponse } from 'axios';

export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
  message?: string;
}

class ApiService {
  private client: AxiosInstance;

  constructor() {
    this.client = axios.create({
      baseURL: import.meta.env.VITE_API_BASE_URL || 'http://localhost:3000/api',
      timeout: 10000,
    });

    this.setupInterceptors();
  }

  private setupInterceptors() {
    // Request interceptor to add auth token
    this.client.interceptors.request.use(
      (config) => {
        const token = localStorage.getItem('admin_token');
        if (token) {
          config.headers.Authorization = `Bearer ${token}`;
        }
        return config;
      },
      (error) => Promise.reject(error)
    );

    // Response interceptor for error handling
    this.client.interceptors.response.use(
      (response) => response,
      (error) => {
        if (error.response?.status === 401) {
          localStorage.removeItem('admin_token');
          window.location.href = '/login';
        }
        return Promise.reject(error);
      }
    );
  }

  async get<T>(url: string, params?: any): Promise<T> {
    const response: AxiosResponse<T> = await this.client.get(url, { params });
    return response.data;
  }

  async post<T>(url: string, data?: any): Promise<T> {
    const response: AxiosResponse<T> = await this.client.post(url, data);
    return response.data;
  }

  async put<T>(url: string, data?: any): Promise<T> {
    const response: AxiosResponse<T> = await this.client.put(url, data);
    return response.data;
  }

  async delete<T>(url: string): Promise<T> {
    const response: AxiosResponse<T> = await this.client.delete(url);
    return response.data;
  }
}

export const apiService = new ApiService();
```

### 2. Authentication Hook

```typescript
// src/hooks/useAuth.ts
import { useState, useEffect, createContext, useContext, ReactNode } from 'react';
import { apiService } from '../services/api';

interface AdminUser {
  id: string;
  email: string;
  role: string;
  lastLoginAt: string;
}

interface AuthContextType {
  user: AdminUser | null;
  isLoading: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AdminUser | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    checkAuthState();
  }, []);

  const checkAuthState = async () => {
    try {
      const token = localStorage.getItem('admin_token');
      if (token) {
        const userData = await apiService.get<{ user: AdminUser }>('/admin/profile');
        setUser(userData.user);
      }
    } catch (error) {
      localStorage.removeItem('admin_token');
    } finally {
      setIsLoading(false);
    }
  };

  const login = async (email: string, password: string) => {
    try {
      const response = await apiService.post<{ token: string; user: AdminUser }>('/admin/login', {
        email,
        password,
      });
      
      localStorage.setItem('admin_token', response.token);
      setUser(response.user);
    } catch (error) {
      throw new Error('Login failed');
    }
  };

  const logout = () => {
    localStorage.removeItem('admin_token');
    setUser(null);
    window.location.href = '/login';
  };

  return (
    <AuthContext.Provider value={{ user, isLoading, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
```

---

## Dashboard Components

### 1. Main Dashboard Layout

```typescript
// src/components/layout/DashboardLayout.tsx
import React from 'react';
import { Outlet, NavLink, useNavigate } from 'react-router-dom';
import { useAuth } from '../../hooks/useAuth';
import {
  HomeIcon,
  DocumentReportIcon,
  HeartIcon,
  UsersIcon,
  LogoutIcon,
} from '@heroicons/react/outline';

const navigation = [
  { name: 'Dashboard', href: '/', icon: HomeIcon },
  { name: 'Reports', href: '/reports', icon: DocumentReportIcon },
  { name: 'Charities', href: '/charities', icon: HeartIcon },
  { name: 'Users', href: '/users', icon: UsersIcon },
];

export function DashboardLayout() {
  const { user, logout } = useAuth();

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Sidebar */}
      <div className="fixed inset-y-0 left-0 z-50 w-64 bg-white shadow-lg">
        <div className="flex h-16 shrink-0 items-center px-6">
          <h1 className="text-xl font-bold text-gray-900">MindLock Admin</h1>
        </div>
        
        <nav className="mt-6 px-3">
          <ul className="space-y-1">
            {navigation.map((item) => (
              <li key={item.name}>
                <NavLink
                  to={item.href}
                  className={({ isActive }) =>
                    `group flex items-center rounded-md px-3 py-2 text-sm font-medium ${
                      isActive
                        ? 'bg-primary-50 text-primary-700'
                        : 'text-gray-700 hover:bg-gray-50 hover:text-gray-900'
                    }`
                  }
                >
                  <item.icon className="mr-3 h-5 w-5 flex-shrink-0" />
                  {item.name}
                </NavLink>
              </li>
            ))}
          </ul>
        </nav>

        <div className="absolute bottom-0 w-full p-4">
          <div className="flex items-center">
            <div className="flex-1">
              <p className="text-sm font-medium text-gray-700">{user?.email}</p>
              <p className="text-xs text-gray-500">{user?.role}</p>
            </div>
            <button
              onClick={logout}
              className="ml-3 rounded-md p-1 text-gray-400 hover:text-gray-500"
            >
              <LogoutIcon className="h-5 w-5" />
            </button>
          </div>
        </div>
      </div>

      {/* Main content */}
      <div className="pl-64">
        <main className="py-6">
          <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
            <Outlet />
          </div>
        </main>
      </div>
    </div>
  );
}
```

### 2. Dashboard Overview

```typescript
// src/pages/Dashboard.tsx
import React from 'react';
import { useQuery } from '@tanstack/react-query';
import { apiService } from '../services/api';
import { StatsCard } from '../components/ui/StatsCard';
import { RevenueChart } from '../components/charts/RevenueChart';
import { DonationChart } from '../components/charts/DonationChart';

interface DashboardStats {
  totalRevenue: number;
  totalDonations: number;
  totalUsers: number;
  totalPurchases: number;
  monthlyGrowth: number;
}

export function Dashboard() {
  const { data: stats, isLoading } = useQuery({
    queryKey: ['dashboard-stats'],
    queryFn: () => apiService.get<DashboardStats>('/admin/dashboard/stats'),
  });

  if (isLoading) {
    return <div>Loading...</div>;
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold text-gray-900">Dashboard</h1>
        <p className="mt-1 text-sm text-gray-500">
          Overview of MindLock performance and donations
        </p>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-4">
        <StatsCard
          title="Total Revenue"
          value={`$${stats?.totalRevenue.toLocaleString()}`}
          change={`+${stats?.monthlyGrowth}%`}
          changeType="positive"
        />
        <StatsCard
          title="Total Donations"
          value={`$${stats?.totalDonations.toLocaleString()}`}
          change="+12%"
          changeType="positive"
        />
        <StatsCard
          title="Active Users"
          value={stats?.totalUsers.toLocaleString()}
          change="+8%"
          changeType="positive"
        />
        <StatsCard
          title="Total Purchases"
          value={stats?.totalPurchases.toLocaleString()}
          change="+15%"
          changeType="positive"
        />
      </div>

      {/* Charts Grid */}
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <div className="bg-white p-6 rounded-lg shadow">
          <h3 className="text-lg font-medium text-gray-900 mb-4">Revenue Trend</h3>
          <RevenueChart />
        </div>
        
        <div className="bg-white p-6 rounded-lg shadow">
          <h3 className="text-lg font-medium text-gray-900 mb-4">Donations by Charity</h3>
          <DonationChart />
        </div>
      </div>
    </div>
  );
}
```

### 3. Stats Card Component

```typescript
// src/components/ui/StatsCard.tsx
import React from 'react';
import { ArrowUpIcon, ArrowDownIcon } from '@heroicons/react/solid';

interface StatsCardProps {
  title: string;
  value: string;
  change?: string;
  changeType?: 'positive' | 'negative';
}

export function StatsCard({ title, value, change, changeType }: StatsCardProps) {
  return (
    <div className="bg-white overflow-hidden shadow rounded-lg">
      <div className="p-5">
        <div className="flex items-center">
          <div className="flex-1">
            <dt className="text-sm font-medium text-gray-500 truncate">{title}</dt>
            <dd className="mt-1 text-3xl font-semibold text-gray-900">{value}</dd>
          </div>
        </div>
        
        {change && (
          <div className="mt-4 flex items-center">
            <div className={`flex items-center text-sm ${
              changeType === 'positive' ? 'text-green-600' : 'text-red-600'
            }`}>
              {changeType === 'positive' ? (
                <ArrowUpIcon className="w-4 h-4 mr-1" />
              ) : (
                <ArrowDownIcon className="w-4 h-4 mr-1" />
              )}
              {change}
            </div>
            <span className="ml-2 text-sm text-gray-500">from last month</span>
          </div>
        )}
      </div>
    </div>
  );
}
```

---

## Reports Management

### 1. Reports Page

```typescript
// src/pages/Reports.tsx
import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { apiService } from '../services/api';
import { format, startOfMonth, endOfMonth } from 'date-fns';
import { DownloadIcon, RefreshIcon } from '@heroicons/react/outline';

interface MonthlyReport {
  id: string;
  month: number;
  year: number;
  charityId: string;
  charityName: string;
  totalAmountCents: number;
  transactionCount: number;
  status: 'pending' | 'generated' | 'exported' | 'paid';
  generatedAt: string;
  exportedAt?: string;
  paidAt?: string;
}

export function Reports() {
  const [selectedMonth, setSelectedMonth] = useState(new Date());
  const queryClient = useQueryClient();

  const { data: reports, isLoading } = useQuery({
    queryKey: ['monthly-reports', selectedMonth.getFullYear(), selectedMonth.getMonth() + 1],
    queryFn: () => 
      apiService.get<{ reports: MonthlyReport[] }>('/admin/monthly-reports', {
        year: selectedMonth.getFullYear(),
        month: selectedMonth.getMonth() + 1,
      }),
  });

  const generateReportMutation = useMutation({
    mutationFn: (params: { month: number; year: number }) =>
      apiService.post('/admin/generate-report', params),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['monthly-reports'] });
    },
  });

  const exportReportMutation = useMutation({
    mutationFn: (params: { month: number; year: number }) =>
      apiService.post('/admin/export-reports', params),
    onSuccess: (data: { csvUrl: string }) => {
      // Download CSV file
      window.open(data.csvUrl, '_blank');
    },
  });

  const handleGenerateReport = () => {
    generateReportMutation.mutate({
      month: selectedMonth.getMonth() + 1,
      year: selectedMonth.getFullYear(),
    });
  };

  const handleExportReport = () => {
    exportReportMutation.mutate({
      month: selectedMonth.getMonth() + 1,
      year: selectedMonth.getFullYear(),
    });
  };

  const totalDonations = reports?.reports.reduce(
    (sum, report) => sum + report.totalAmountCents,
    0
  ) || 0;

  return (
    <div className="space-y-6">
      <div className="sm:flex sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-gray-900">Monthly Reports</h1>
          <p className="mt-1 text-sm text-gray-500">
            Generate and export charity donation reports
          </p>
        </div>
        
        <div className="mt-4 sm:mt-0 sm:flex sm:space-x-3">
          <button
            onClick={handleGenerateReport}
            disabled={generateReportMutation.isPending}
            className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-primary-600 hover:bg-primary-700 disabled:opacity-50"
          >
            {generateReportMutation.isPending ? (
              <RefreshIcon className="w-4 h-4 mr-2 animate-spin" />
            ) : (
              <RefreshIcon className="w-4 h-4 mr-2" />
            )}
            Generate Report
          </button>
          
          <button
            onClick={handleExportReport}
            disabled={exportReportMutation.isPending || !reports?.reports.length}
            className="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 disabled:opacity-50"
          >
            <DownloadIcon className="w-4 h-4 mr-2" />
            Export CSV
          </button>
        </div>
      </div>

      {/* Month Selector */}
      <div className="bg-white shadow rounded-lg p-6">
        <div className="flex items-center space-x-4">
          <label htmlFor="month-select" className="text-sm font-medium text-gray-700">
            Select Month:
          </label>
          <input
            id="month-select"
            type="month"
            value={format(selectedMonth, 'yyyy-MM')}
            onChange={(e) => setSelectedMonth(new Date(e.target.value))}
            className="rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500"
          />
          
          <div className="flex-1 text-right">
            <span className="text-sm text-gray-500">Total Donations: </span>
            <span className="text-lg font-semibold text-gray-900">
              ${(totalDonations / 100).toLocaleString()}
            </span>
          </div>
        </div>
      </div>

      {/* Reports Table */}
      <div className="bg-white shadow rounded-lg overflow-hidden">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Charity
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Amount
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Transactions
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Status
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Generated
              </th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {reports?.reports.map((report) => (
              <tr key={report.id}>
                <td className="px-6 py-4 whitespace-nowrap">
                  <div className="text-sm font-medium text-gray-900">
                    {report.charityName}
                  </div>
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <div className="text-sm text-gray-900">
                    ${(report.totalAmountCents / 100).toLocaleString()}
                  </div>
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <div className="text-sm text-gray-900">
                    {report.transactionCount}
                  </div>
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <StatusBadge status={report.status} />
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {format(new Date(report.generatedAt), 'MMM d, yyyy')}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        
        {!isLoading && !reports?.reports.length && (
          <div className="text-center py-12">
            <p className="text-gray-500">No reports found for selected month</p>
          </div>
        )}
      </div>
    </div>
  );
}

function StatusBadge({ status }: { status: string }) {
  const colors = {
    pending: 'bg-yellow-100 text-yellow-800',
    generated: 'bg-blue-100 text-blue-800',
    exported: 'bg-green-100 text-green-800',
    paid: 'bg-purple-100 text-purple-800',
  };

  return (
    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${colors[status as keyof typeof colors]}`}>
      {status.charAt(0).toUpperCase() + status.slice(1)}
    </span>
  );
}
```

---

## Charts Components

### 1. Revenue Chart

```typescript
// src/components/charts/RevenueChart.tsx
import React from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';
import { useQuery } from '@tanstack/react-query';
import { apiService } from '../../services/api';

interface RevenueData {
  month: string;
  revenue: number;
  donations: number;
}

export function RevenueChart() {
  const { data, isLoading } = useQuery({
    queryKey: ['revenue-chart'],
    queryFn: () => apiService.get<{ data: RevenueData[] }>('/admin/charts/revenue'),
  });

  if (isLoading) {
    return <div className="h-64 flex items-center justify-center">Loading...</div>;
  }

  return (
    <div className="h-64">
      <ResponsiveContainer width="100%" height="100%">
        <LineChart data={data?.data}>
          <CartesianGrid strokeDasharray="3 3" />
          <XAxis dataKey="month" />
          <YAxis />
          <Tooltip 
            formatter={(value: number, name: string) => [
              `$${value.toLocaleString()}`,
              name === 'revenue' ? 'Revenue' : 'Donations'
            ]}
          />
          <Line 
            type="monotone" 
            dataKey="revenue" 
            stroke="#3b82f6" 
            strokeWidth={2}
            name="revenue"
          />
          <Line 
            type="monotone" 
            dataKey="donations" 
            stroke="#ef4444" 
            strokeWidth={2}
            name="donations"
          />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}
```

### 2. Donation Distribution Chart

```typescript
// src/components/charts/DonationChart.tsx
import React from 'react';
import { PieChart, Pie, Cell, ResponsiveContainer, Tooltip, Legend } from 'recharts';
import { useQuery } from '@tanstack/react-query';
import { apiService } from '../../services/api';

interface DonationDistribution {
  charityName: string;
  amount: number;
  percentage: number;
}

const COLORS = ['#3b82f6', '#ef4444', '#10b981', '#f59e0b', '#8b5cf6'];

export function DonationChart() {
  const { data, isLoading } = useQuery({
    queryKey: ['donation-distribution'],
    queryFn: () => apiService.get<{ data: DonationDistribution[] }>('/admin/charts/donations'),
  });

  if (isLoading) {
    return <div className="h-64 flex items-center justify-center">Loading...</div>;
  }

  return (
    <div className="h-64">
      <ResponsiveContainer width="100%" height="100%">
        <PieChart>
          <Pie
            data={data?.data}
            cx="50%"
            cy="50%"
            labelLine={false}
            label={({ charityName, percentage }) => `${charityName} ${percentage}%`}
            outerRadius={80}
            fill="#8884d8"
            dataKey="amount"
          >
            {data?.data.map((entry, index) => (
              <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
            ))}
          </Pie>
          <Tooltip formatter={(value: number) => [`$${value.toLocaleString()}`, 'Amount']} />
        </PieChart>
      </ResponsiveContainer>
    </div>
  );
}
```

---

## Charity Management

### 1. Charities Page

```typescript
// src/pages/Charities.tsx
import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { apiService } from '../services/api';
import { PlusIcon, PencilIcon, TrashIcon } from '@heroicons/react/outline';

interface Charity {
  id: string;
  name: string;
  description: string;
  website?: string;
  logoUrl?: string;
  category?: string;
  isActive: boolean;
  isVerified: boolean;
  totalDonations: number;
  userCount: number;
}

export function Charities() {
  const [showAddModal, setShowAddModal] = useState(false);
  const [editingCharity, setEditingCharity] = useState<Charity | null>(null);
  const queryClient = useQueryClient();

  const { data: charities, isLoading } = useQuery({
    queryKey: ['charities'],
    queryFn: () => apiService.get<{ charities: Charity[] }>('/admin/charities'),
  });

  const deleteCharityMutation = useMutation({
    mutationFn: (id: string) => apiService.delete(`/admin/charities/${id}`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['charities'] });
    },
  });

  const toggleActiveMutation = useMutation({
    mutationFn: ({ id, isActive }: { id: string; isActive: boolean }) =>
      apiService.put(`/admin/charities/${id}`, { isActive }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['charities'] });
    },
  });

  return (
    <div className="space-y-6">
      <div className="sm:flex sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-gray-900">Charities</h1>
          <p className="mt-1 text-sm text-gray-500">
            Manage charity organizations and donation recipients
          </p>
        </div>
        
        <button
          onClick={() => setShowAddModal(true)}
          className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-primary-600 hover:bg-primary-700"
        >
          <PlusIcon className="w-4 h-4 mr-2" />
          Add Charity
        </button>
      </div>

      {/* Charities Table */}
      <div className="bg-white shadow rounded-lg overflow-hidden">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Charity
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Category
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Total Donations
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Users
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Status
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Actions
              </th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {charities?.charities.map((charity) => (
              <tr key={charity.id}>
                <td className="px-6 py-4 whitespace-nowrap">
                  <div className="flex items-center">
                    {charity.logoUrl && (
                      <img 
                        className="h-8 w-8 rounded-full mr-3" 
                        src={charity.logoUrl} 
                        alt={charity.name}
                      />
                    )}
                    <div>
                      <div className="text-sm font-medium text-gray-900">
                        {charity.name}
                      </div>
                      <div className="text-sm text-gray-500">
                        {charity.website}
                      </div>
                    </div>
                  </div>
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                    {charity.category || 'General'}
                  </span>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  ${charity.totalDonations.toLocaleString()}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {charity.userCount}
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <div className="flex items-center space-x-2">
                    {charity.isVerified && (
                      <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                        Verified
                      </span>
                    )}
                    <button
                      onClick={() => toggleActiveMutation.mutate({ 
                        id: charity.id, 
                        isActive: !charity.isActive 
                      })}
                      className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                        charity.isActive 
                          ? 'bg-green-100 text-green-800' 
                          : 'bg-red-100 text-red-800'
                      }`}
                    >
                      {charity.isActive ? 'Active' : 'Inactive'}
                    </button>
                  </div>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                  <div className="flex items-center space-x-2">
                    <button
                      onClick={() => setEditingCharity(charity)}
                      className="text-indigo-600 hover:text-indigo-900"
                    >
                      <PencilIcon className="w-4 h-4" />
                    </button>
                    <button
                      onClick={() => deleteCharityMutation.mutate(charity.id)}
                      className="text-red-600 hover:text-red-900"
                    >
                      <TrashIcon className="w-4 h-4" />
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Add/Edit Charity Modal would go here */}
    </div>
  );
}
```

---

## Deployment

### 1. Build Configuration

```json
{
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "preview": "vite preview",
    "deploy": "npm run build && firebase deploy"
  }
}
```

### 2. Environment Variables

```bash
# .env.production
VITE_API_BASE_URL=https://your-backend-url.com/api
VITE_APP_NAME=MindLock Admin
```

### 3. Firebase Hosting Setup

```json
{
  "hosting": {
    "public": "dist",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ]
  }
}
```

This admin dashboard provides comprehensive management capabilities for the MindLock platform, including donation tracking, charity management, and detailed reporting features. 