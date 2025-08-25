import React, { useState } from 'react';

interface TableProps {
  data: Array<{
    event: string;
    eventId: string;
    object: string;
    status: 'Success' | 'Failed' | 'Pending';
    responseCode: string;
    createdAt: string;
  }>;
}

const InventoryManagement: React.FC<TableProps> = () => {
  const [filter, setFilter] = useState<'All' | 'Success' | 'Failed' | 'Pending'>('All');

  const data = [
    {
      startedAt: '2021-01-03 12:00:00',
      finishedAt: '2021-01-03 14:35:00',
      status: 'Pending',
      responseCode: '200',
    },
    {
      startedAt: '2021-01-02 12:00:00',
      finishedAt: '2021-01-02 14:35:00',
      status: 'Success',
      responseCode: '200',
    },
    {
      startedAt: '2021-01-01 12:00:00',
      finishedAt: '2021-01-01 14:35:00',
      status: 'Failed',
      responseCode: '200',
    }
  ];

  const filteredData = data.filter(item => {
    const matchesFilter = filter === 'All' || item.status === filter;
    return matchesFilter;
  });

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'Success':
        return 'bg-green-100 text-green-800';
      case 'Failed':
        return 'bg-red-100 text-red-800';
      case 'Pending':
        return 'bg-yellow-100 text-yellow-800';
      default:
        return 'bg-gray-100 text-gray-800';
    }
  };

  const getStatusDot = (status: string) => {
    switch (status) {
      case 'Success':
        return 'bg-green-500';
      case 'Failed':
        return 'bg-red-500';
      case 'Pending':
        return 'bg-yellow-500';
      default:
        return 'bg-gray-500';
    }
  };

  return (
    <div className="bg-white rounded-lg shadow mt-4">
      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Started At</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Finished At</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Response Code</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"></th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {filteredData.map((item, index) => (
              <tr key={index} className="hover:bg-gray-50">
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{item.startedAt}</td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{item.finishedAt}</td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getStatusColor(item.status)}`}>
                    <span className={`w-2 h-2 rounded-full mr-2 ${getStatusDot(item.status)}`}></span>
                    {item.status}
                  </span>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{item.responseCode}</td>
                <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                  <button className="text-gray-400 hover:text-gray-600">
                    <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                      <path d="M10 6a2 2 0 110-4 2 2 0 010 4zM10 12a2 2 0 110-4 2 2 0 010 4zM10 18a2 2 0 110-4 2 2 0 010 4z" />
                    </svg>
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
};

export default InventoryManagement;
