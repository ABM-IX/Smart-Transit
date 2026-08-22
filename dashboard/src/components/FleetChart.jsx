import React from 'react';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Filler,
  Tooltip,
} from 'chart.js';
import { Line } from 'react-chartjs-2';

ChartJS.register(CategoryScale, LinearScale, PointElement, LineElement, Filler, Tooltip);

export default function FleetChart({ dataPoints = [4, 6, 8, 7, 10, 12, 11, 14, 15, 13, 16, 18, 17, 19, 20] }) {
  const chartData = {
    labels: Array(dataPoints.length).fill(''),
    datasets: [
      {
        data: dataPoints,
        borderColor: '#5B8CFF',
        backgroundColor: 'rgba(91, 140, 255, 0.14)',
        borderWidth: 2,
        fill: true,
        tension: 0.4,
        pointRadius: 0,
      },
    ],
  };

  const options = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: { display: false },
      tooltip: { enabled: true },
    },
    scales: {
      x: { display: false },
      y: {
        display: false,
        beginAtZero: true,
      },
    },
  };

  return (
    <section>
      <div className="section-label">Fleet Load Distribution</div>
      <div style={{ height: '110px', width: '100%' }}>
        <Line data={chartData} options={options} />
      </div>
    </section>
  );
}
