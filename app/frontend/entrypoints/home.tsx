import React, { useState } from 'react';
import { createRoot } from 'react-dom/client';
import ConfigurationForm from "../components/ConfigurationForm";

interface FluidProps {
  companyId: string;
  storeName: string;
  warehouseName: string;
  username: string;
  password: string;
  fluidApiToken: string;
}

// Interfaces
interface TabItem {
  id: string;
  label: string;
  component: React.ComponentType<any>;
  props?: any;
}

interface TabsProps {
  tabs: TabItem[];
  defaultTab?: string;
  className?: string;
}

interface TabContentProps {
  tabs: TabItem[];
  activeTab: string;
}

const Tabs: React.FC<TabsProps> = ({ tabs, defaultTab, className = '' }) => {
  const [activeTab, setActiveTab] = useState(defaultTab || tabs[0]?.id || '');

  return (
    <div className={className}>
      <div className="border-b border-gray-200">
        <nav className="-mb-px flex space-x-8">
          {tabs.map((tab) => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`py-2 px-1 border-b-2 font-medium text-sm ${activeTab === tab.id
                  ? 'border-gray-900 text-gray-900'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                }`}
            >
              {tab.label}
            </button>
          ))}
        </nav>
      </div>
      <TabContent tabs={tabs} activeTab={activeTab} />
    </div>
  );
};

const TabContent: React.FC<TabContentProps> = ({ tabs, activeTab }) => {
  const activeTabData = tabs.find(tab => tab.id === activeTab);

  if (!activeTabData) return null;

  const Component = activeTabData.component;
  return <Component {...activeTabData.props} />;
};

const Fluid = ({ companyId, storeName, warehouseName, username, password, fluidApiToken }: FluidProps) => {
  const tabs: TabItem[] = [
    {
      id: 'configuration',
      label: 'Configuration',
      component: ConfigurationForm,
      props: { companyId, storeName, warehouseName, username, password, fluidApiToken }
    }
  ];

  return (
    <div className="min-h-screen bg-gray-100 p-6">
      <div className="max-w-6xl mx-auto">
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
          <Tabs tabs={tabs} defaultTab="configuration" />
        </div>
      </div>
    </div>
  );
};

const root = createRoot(document.getElementById('root') as HTMLElement);

const rootElement = document.getElementById('root') as HTMLElement;
const companyId = rootElement.dataset.companyId || '';
const storeName = rootElement.dataset.storeName || '';
const warehouseName = rootElement.dataset.warehouseName || '';
const username = rootElement.dataset.username || '';
const password = rootElement.dataset.password || '';
const fluidApiToken = rootElement.dataset.fluidApiToken || '';

root.render(<Fluid companyId={companyId} storeName={storeName} warehouseName={warehouseName} username={username} password={password} fluidApiToken={fluidApiToken} />);
