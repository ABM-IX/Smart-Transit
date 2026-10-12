import React from 'react';
import {
  ArcElement,
  Chart as ChartJS,
  Legend,
  Tooltip,
} from 'chart.js';
import { Doughnut } from 'react-chartjs-2';

ChartJS.register(ArcElement, Legend, Tooltip);

export default function FleetChart({ modeCounts = {} }) {
  const counts = {
    Bus: modeCounts.BUS || 0,
    Combi: modeCounts.COMBI || 0,
    Taxi: modeCounts.TAXI || 0,
  };
  const total = Object.values(counts).reduce((sum, value) => sum + value, 0);

  if (total === 0) {
    return (
      <div className="chart-empty">
        <strong>No fleet telemetry</strong>
        <span>The chart will populate when live driver records arrive.</span>
      </div>
    );
  }

  const data = {
    labels: Object.keys(counts),
    datasets: [
      {
        data: Object.values(counts),
        backgroundColor: ['#60a5fa', '#22d3ee', '#f59e0b'],
        borderColor: '#0f172a',
        borderWidth: 2,
      },
    ],
  };

  const options = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        position: 'bottom',
        labels: { color: '#cbd5e1', boxWidth: 10, usePointStyle: true },
      },
      tooltip: { enabled: true },
    },
  };

  return (
    <div className="chart-panel">
      <Doughnut data={data} options={options} />
    </div>
  );
}
